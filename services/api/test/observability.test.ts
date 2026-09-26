import test from "node:test";
import assert from "node:assert/strict";
import {
  buildStructuredLog,
  createRequestContext,
  normalizeRequestId,
  processHealth,
  redactLogDetails,
  requestPath
} from "../src/observability.js";

test("request IDs accept safe values and replace log-injection input", () => {
  assert.equal(normalizeRequestId("req-123"), "req-123");

  const replaced = normalizeRequestId("bad\r\nforged");
  assert.notEqual(replaced, "bad\r\nforged");
  assert.match(replaced, /^[0-9a-f-]{36}$/);
});

test("request path never exposes query parameters", () => {
  assert.equal(
    requestPath("/orders?token=secret&customer=123"),
    "/orders"
  );
  assert.equal(requestPath(undefined), "/");
});

test("log detail redaction removes common secrets and personal contact data", () => {
  assert.deepEqual(
    redactLogDetails({
      status: "failed",
      email: "person@example.com",
      nested: {
        authorization: "Bearer secret",
        count: 2
      },
      entries: [
        {
          phone: "+919999999999",
          state: "pending"
        }
      ]
    }),
    {
      status: "failed",
      email: "[REDACTED]",
      nested: {
        authorization: "[REDACTED]",
        count: 2
      },
      entries: [
        {
          phone: "[REDACTED]",
          state: "pending"
        }
      ]
    }
  );
});

test("structured request log is correlation-safe and deterministic", () => {
  const context = createRequestContext({
    requestIdHeader: "req-1",
    method: "get",
    url: "/health?secret=value",
    nowMs: 100
  });

  const record = buildStructuredLog({
    level: "info",
    event: "http_request_completed",
    now: new Date("2026-09-26T10:00:00Z"),
    request: context,
    statusCode: 200,
    durationMs: 12.7,
    details: { token: "hidden", result: "ok" }
  });

  assert.equal(record.requestId, "req-1");
  assert.equal(record.path, "/health");
  assert.equal(record.durationMs, 13);
  assert.deepEqual(record.details, {
    token: "[REDACTED]",
    result: "ok"
  });
});

test("process health states its readiness scope explicitly", () => {
  assert.deepEqual(
    processHealth({ requestId: "req-2", uptimeSeconds: 12.8 }),
    {
      status: "ok",
      service: "aaraapos-api",
      scope: "process",
      uptimeSeconds: 12,
      requestId: "req-2"
    }
  );
});
