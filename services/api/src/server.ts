import { randomUUID } from "node:crypto";
import { createServer } from "node:http";

const port = Number(process.env.PORT ?? 3000);

const server = createServer((request, response) => {
  const requestId = request.headers["x-request-id"]?.toString() ?? randomUUID();

  response.setHeader("content-type", "application/json; charset=utf-8");
  response.setHeader("x-request-id", requestId);

  if (request.method === "GET" && request.url === "/health") {
    response.statusCode = 200;
    response.end(JSON.stringify({ status: "ok", service: "aaraapos-api", requestId }));
    return;
  }

  response.statusCode = 404;
  response.end(JSON.stringify({
    code: "NOT_FOUND",
    message: "Resource not found.",
    requestId
  }));
});

server.listen(port, "0.0.0.0", () => {
  process.stdout.write(
    JSON.stringify({ level: "info", message: "api_started", port }) + "\n"
  );
});
