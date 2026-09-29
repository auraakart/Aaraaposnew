import { createServer, type IncomingMessage, type ServerResponse } from "node:http";

import { createApiHandler } from "./api.js";
import { UnconfiguredRequestAuthenticator } from "./authenticator.js";
import {
  buildStructuredLog,
  createRequestContext,
  processHealth,
  writeStructuredLog
} from "./observability.js";

const port = Number(process.env.PORT ?? 3000);
const maxBodyBytes = 256 * 1024;
const api = createApiHandler({
  authenticator: new UnconfiguredRequestAuthenticator()
});

class PayloadTooLargeError extends Error {}

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
  body: Readonly<Record<string, unknown>>
): void {
  response.statusCode = statusCode;
  response.end(JSON.stringify(body));
}

async function handleRequest(
  request: IncomingMessage,
  response: ServerResponse
): Promise<void> {
  const requestIdHeader = request.headers["x-request-id"];
  const context = createRequestContext({
    requestIdHeader: Array.isArray(requestIdHeader)
      ? requestIdHeader[0]
      : requestIdHeader,
    method: request.method,
    url: request.url
  });

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

  if (
    request.method === "GET" &&
    (context.path === "/health" || context.path === "/ready")
  ) {
    writeJson(
      response,
      200,
      processHealth({
        requestId: context.requestId
      })
    );
    return;
  }

  try {
    const bodyText = await readBody(request, maxBodyBytes);
    const authorizationHeader = request.headers.authorization;
    const result = await api.handle({
      method: (request.method ?? "UNKNOWN").toUpperCase(),
      path: context.path,
      authorizationHeader: Array.isArray(authorizationHeader)
        ? authorizationHeader[0]
        : authorizationHeader,
      bodyText,
      requestId: context.requestId,
      now: new Date()
    });
    writeJson(response, result.statusCode, result.body);
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

server.listen(port, "0.0.0.0", () => {
  writeStructuredLog(
    buildStructuredLog({
      level: "info",
      event: "api_started",
      details: { port }
    })
  );
});
