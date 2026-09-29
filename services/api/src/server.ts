import { createServer, type IncomingMessage, type ServerResponse } from "node:http";

import { allowedMethodsForPath, createApiHandler } from "./api.js";
import { UnconfiguredRequestAuthenticator } from "./authenticator.js";
import { createPostgresDatabaseFromEnvironment } from "./database.js";
import {
  apiSecurityHeaders,
  evaluateCors,
  FixedWindowRateLimiter,
  isJsonContentType,
  parseAllowedOrigins,
  rateLimitHeaders
} from "./edge_security.js";
import {
  buildStructuredLog,
  createRequestContext,
  processHealth,
  writeStructuredLog
} from "./observability.js";

const port = Number(process.env.PORT ?? 3000);
const maxBodyBytes = 256 * 1024;
const corsPolicy = {
  allowedOrigins: parseAllowedOrigins(process.env.CORS_ALLOWED_ORIGINS)
};
const rateLimiter = new FixedWindowRateLimiter(120, 60_000, 10_000);
const api = createApiHandler({
  authenticator: new UnconfiguredRequestAuthenticator()
});
const database = createPostgresDatabaseFromEnvironment(process.env);

class PayloadTooLargeError extends Error {}

function firstHeader(
  value: string | readonly string[] | undefined
): string | undefined {
  return typeof value === "string" ? value : value?.[0];
}

function setHeaders(
  response: ServerResponse,
  headers: Readonly<Record<string, string>>
): void {
  for (const [name, value] of Object.entries(headers)) {
    response.setHeader(name, value);
  }
}

async function readBody(
  request: IncomingMessage,
  limit: number
): Promise<string | undefined> {
  if (request.method === "GET" || request.method === "HEAD") {
    return undefined;
  }

  const chunks: Buffer[] = [];
  let total = 0;
  for await (const chunk of request) {
    const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
    total += buffer.length;
    if (total > limit) {
      throw new PayloadTooLargeError();
    }
    chunks.push(buffer);
  }
  return chunks.length === 0
    ? undefined
    : Buffer.concat(chunks).toString("utf8");
}

function writeJson(
  response: ServerResponse,
  statusCode: number,
  body: Readonly<Record<string, unknown>>,
  headers: Readonly<Record<string, string>> = {}
): void {
  setHeaders(response, headers);
  response.statusCode = statusCode;
  response.end(JSON.stringify(body));
}

async function handleRequest(
  request: IncomingMessage,
  response: ServerResponse
): Promise<void> {
  const requestIdHeader = firstHeader(request.headers["x-request-id"]);
  const context = createRequestContext({
    requestIdHeader,
    method: request.method,
    url: request.url
  });

  setHeaders(response, apiSecurityHeaders());
  response.setHeader("content-type", "application/json; charset=utf-8");
  response.setHeader("x-request-id", context.requestId);

  response.once("finish", () => {
    writeStructuredLog(
      buildStructuredLog({
        level: response.statusCode >= 500 ? "error" : "info",
        event: "http_request_completed",
        request: context,
        statusCode: response.statusCode,
        durationMs: Date.now() - context.startedAtMs
      })
    );
  });

  if (request.method === "GET" && context.path === "/health") {
    writeJson(
      response,
      200,
      processHealth({
        requestId: context.requestId
      })
    );
    return;
  }

  if (request.method === "GET" && context.path === "/ready") {
    if (database === undefined) {
      writeJson(response, 503, {
        status: "not_ready",
        service: "aaraapos-api",
        scope: "dependencies",
        dependencies: { database: "NOT_CONFIGURED" },
        requestId: context.requestId
      });
      return;
    }

    const readiness = await database.readiness();
    writeJson(response, readiness.ready ? 200 : 503, {
      status: readiness.ready ? "ok" : "not_ready",
      service: "aaraapos-api",
      scope: "dependencies",
      dependencies: { database: readiness.code },
      requestId: context.requestId
    });
    return;
  }

  const isVersionedApi = context.path.startsWith("/v1/");
  const allowedMethods = allowedMethodsForPath(context.path);
  const isKnownPreflight =
    request.method === "OPTIONS" && allowedMethods.length > 0;

  if (isVersionedApi) {
    const cors = evaluateCors(
      firstHeader(request.headers.origin),
      corsPolicy,
      isKnownPreflight
    );
    setHeaders(response, cors.headers);

    if (!cors.allowed) {
      writeJson(response, 403, {
        code: "CORS_ORIGIN_DENIED",
        message: "Browser origin is not allowed.",
        requestId: context.requestId
      });
      return;
    }

    const clientAddress = request.socket.remoteAddress ?? "unknown";
    const rateDecision = rateLimiter.check(
      `${clientAddress}|${context.path}`,
      Date.now()
    );
    setHeaders(response, rateLimitHeaders(rateDecision));
    if (!rateDecision.allowed) {
      const retryAfterSeconds = Math.max(
        1,
        rateDecision.resetAtEpochSeconds -
          Math.floor(Date.now() / 1000)
      );
      writeJson(response, 429, {
        code: "RATE_LIMITED",
        message: "Too many requests.",
        requestId: context.requestId
      }, {
        "retry-after": String(retryAfterSeconds)
      });
      return;
    }

    if (isKnownPreflight) {
      response.removeHeader("content-type");
      response.setHeader(
        "allow",
        [...allowedMethods, "OPTIONS"].join(", ")
      );
      response.statusCode = 204;
      response.end();
      return;
    }

    const method = (request.method ?? "UNKNOWN").toUpperCase();
    if (
      allowedMethods.length > 0 &&
      !allowedMethods.includes(method)
    ) {
      const result = await api.handle({
        method,
        path: context.path,
        authorizationHeader: firstHeader(request.headers.authorization),
        requestId: context.requestId,
        now: new Date()
      });
      writeJson(
        response,
        result.statusCode,
        result.body,
        result.headers ?? {}
      );
      return;
    }

    const methodAcceptsJsonBody =
      (method === "POST" || method === "PUT" || method === "PATCH") &&
      allowedMethods.includes(method);

    if (
      methodAcceptsJsonBody &&
      !isJsonContentType(firstHeader(request.headers["content-type"]))
    ) {
      writeJson(response, 415, {
        code: "UNSUPPORTED_MEDIA_TYPE",
        message: "Protected write requests require application/json.",
        requestId: context.requestId
      });
      return;
    }
  }

  try {
    const bodyText = await readBody(request, maxBodyBytes);
    const authorizationHeader = firstHeader(
      request.headers.authorization
    );
    const result = await api.handle({
      method: (request.method ?? "UNKNOWN").toUpperCase(),
      path: context.path,
      authorizationHeader,
      bodyText,
      requestId: context.requestId,
      now: new Date()
    });
    writeJson(
      response,
      result.statusCode,
      result.body,
      result.headers ?? {}
    );
  } catch (error) {
    if (error instanceof PayloadTooLargeError) {
      writeJson(response, 413, {
        code: "PAYLOAD_TOO_LARGE",
        message: "Request body exceeds 256 KiB.",
        requestId: context.requestId
      });
      return;
    }

    writeJson(response, 500, {
      code: "INTERNAL_ERROR",
      message: "Request could not be processed.",
      requestId: context.requestId
    });
  }
}

const server = createServer((request, response) => {
  void handleRequest(request, response);
});

server.requestTimeout = 15_000;
server.headersTimeout = 10_000;
server.keepAliveTimeout = 5_000;
server.maxHeadersCount = 100;

server.listen(port, "0.0.0.0", () => {
  writeStructuredLog(
    buildStructuredLog({
      level: "info",
      event: "api_started",
      details: {
        port,
        corsOriginCount: corsPolicy.allowedOrigins.size,
        requestTimeoutMs: server.requestTimeout,
        databaseConfigured: database !== undefined
      }
    })
  );
});
