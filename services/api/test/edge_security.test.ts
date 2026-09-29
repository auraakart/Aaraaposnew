import test from "node:test";
import assert from "node:assert/strict";

import {
  apiSecurityHeaders,
  evaluateCors,
  FixedWindowRateLimiter,
  isJsonContentType,
  parseAllowedOrigins,
  rateLimitHeaders
} from "../src/edge_security.js";

test("CORS allowlist is exact and HTTPS-first", () => {
  const allowed = parseAllowedOrigins(
    "https://admin.example.com,http://localhost:5173"
  );

  assert.deepEqual(
    [...allowed],
    ["https://admin.example.com", "http://localhost:5173"]
  );

  assert.throws(() =>
    parseAllowedOrigins("http://admin.example.com")
  );
  assert.throws(() =>
    parseAllowedOrigins("https://admin.example.com/path")
  );
});

test("browser origin is deny-by-default and exact-match only", () => {
  const policy = {
    allowedOrigins: parseAllowedOrigins("https://admin.example.com")
  };

  assert.deepEqual(
    evaluateCors(undefined, policy, false),
    { allowed: true, headers: {} }
  );

  assert.equal(
    evaluateCors("https://evil.example.com", policy, false).allowed,
    false
  );
  assert.equal(
    evaluateCors("https://admin.example.com/path", policy, false).allowed,
    false
  );

  const allowed = evaluateCors(
    "https://admin.example.com",
    policy,
    false
  );
  assert.equal(allowed.allowed, true);
  assert.equal(
    allowed.headers["access-control-allow-origin"],
    "https://admin.example.com"
  );
  assert.equal(allowed.headers.vary, "Origin");
});

test("allowed preflight exposes only controlled methods and headers", () => {
  const decision = evaluateCors(
    "https://admin.example.com",
    {
      allowedOrigins: parseAllowedOrigins("https://admin.example.com")
    },
    true
  );

  assert.equal(decision.allowed, true);
  assert.equal(
    decision.headers["access-control-allow-methods"],
    "GET, POST, OPTIONS"
  );
  assert.equal(
    decision.headers["access-control-allow-headers"],
    "Authorization, Content-Type, X-Request-ID"
  );
  assert.equal(decision.headers["access-control-max-age"], "600");
});

test("security headers prevent caching and common browser embedding", () => {
  const headers = apiSecurityHeaders();

  assert.equal(headers["cache-control"], "no-store");
  assert.equal(headers["x-content-type-options"], "nosniff");
  assert.equal(headers["x-frame-options"], "DENY");
  assert.match(
    headers["content-security-policy"] ?? "",
    /default-src 'none'/
  );
});

test("JSON content type accepts parameters but rejects lookalikes", () => {
  assert.equal(isJsonContentType("application/json"), true);
  assert.equal(
    isJsonContentType("Application/JSON; charset=utf-8"),
    true
  );
  assert.equal(isJsonContentType("text/json"), false);
  assert.equal(isJsonContentType("application/problem+json"), false);
  assert.equal(isJsonContentType(undefined), false);
});

test("fixed window limiter is bounded and resets cleanly", () => {
  const limiter = new FixedWindowRateLimiter(2, 1000, 2);

  const first = limiter.check("client-a", 1000);
  const second = limiter.check("client-a", 1001);
  const third = limiter.check("client-a", 1002);

  assert.equal(first.allowed, true);
  assert.equal(first.remaining, 1);
  assert.equal(second.allowed, true);
  assert.equal(second.remaining, 0);
  assert.equal(third.allowed, false);
  assert.equal(third.remaining, 0);

  const reset = limiter.check("client-a", 2000);
  assert.equal(reset.allowed, true);
  assert.equal(reset.remaining, 1);

  limiter.check("client-b", 2000);
  limiter.check("client-c", 2000);
  assert.equal(limiter.check("client-c", 2001).allowed, true);
});

test("rate limit headers contain no client identity", () => {
  assert.deepEqual(
    rateLimitHeaders({
      allowed: false,
      limit: 120,
      remaining: 0,
      resetAtEpochSeconds: 1234
    }),
    {
      "ratelimit-limit": "120",
      "ratelimit-remaining": "0",
      "ratelimit-reset": "1234"
    }
  );
});
