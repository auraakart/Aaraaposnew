import { createServer } from "node:http";

import {
  buildStructuredLog,
  createRequestContext,
  processHealth,
  writeStructuredLog
} from "./observability.js";

const port = Number(process.env.PORT ?? 3000);

const server = createServer((request, response) => {
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
    response.statusCode = 200;
    response.end(
      JSON.stringify(
        processHealth({
          requestId: context.requestId
        })
      )
    );
    return;
  }

  response.statusCode = 404;
  response.end(
    JSON.stringify({
      code: "NOT_FOUND",
      message: "Resource not found.",
      requestId: context.requestId
    })
  );
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
