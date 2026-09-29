import test from "node:test";
import assert from "node:assert/strict";

import { createApiHandler } from "../src/api.js";
import {
  AuthenticationError,
  UnconfiguredRequestAuthenticator,
  type AuthenticationInput,
  type RequestAuthenticator
} from "../src/authenticator.js";
import type { AuthenticatedPrincipal } from "../src/security.js";

class FixedAuthenticator implements RequestAuthenticator {
  constructor(private readonly principal: AuthenticatedPrincipal) {}

  async authenticate(
    _input: AuthenticationInput
  ): Promise<AuthenticatedPrincipal> {
    return this.principal;
  }
}

class RejectingAuthenticator implements RequestAuthenticator {
  async authenticate(
    _input: AuthenticationInput
  ): Promise<AuthenticatedPrincipal> {
    throw new AuthenticationError();
  }
}

const cashier: AuthenticatedPrincipal = {
  userId: "cashier-1",
  organizationId: "org-1",
  businessIds: ["business-1"],
  storeIds: ["store-1"],
  role: "cashier"
};

const stockWorker: AuthenticatedPrincipal = {
  ...cashier,
  userId: "stock-1",
  role: "stock_worker"
};

function quoteBody(overrides: Record<string, unknown> = {}): string {
  return JSON.stringify({
    organizationId: "org-1",
    businessId: "business-1",
    storeId: "store-1",
    taxMode: "intra_state",
    lines: [
      {
        productId: "product-1",
        name: "Milk",
        unitPriceMinor: 10500,
        quantityMilli: 1000,
        discountMinor: 0,
        taxRateBps: 500,
        taxPriceMode: "inclusive"
      }
    ],
    ...overrides
  });
}

test("GET /v1/session returns only authenticated principal scope", async () => {
  const api = createApiHandler({
    authenticator: new FixedAuthenticator(cashier)
  });

  const response = await api.handle({
    method: "GET",
    path: "/v1/session",
    requestId: "req-1",
    now: new Date("2026-09-29T01:00:00Z")
  });

  assert.equal(response.statusCode, 200);
  assert.deepEqual(response.body, {
    requestId: "req-1",
    userId: "cashier-1",
    organizationId: "org-1",
    businessIds: ["business-1"],
    storeIds: ["store-1"],
    role: "cashier"
  });
});

test("cashier can request an in-scope deterministic sale quote", async () => {
  const api = createApiHandler({
    authenticator: new FixedAuthenticator(cashier)
  });

  const response = await api.handle({
    method: "POST",
    path: "/v1/sales/quote",
    bodyText: quoteBody(),
    requestId: "req-2",
    now: new Date("2026-09-29T01:00:00Z")
  });

  assert.equal(response.statusCode, 200);
  const totals = response.body.totals as {
    totalMinor: number;
    taxMinor: number;
  };
  assert.equal(totals.totalMinor, 10500);
  assert.equal(totals.taxMinor, 500);
});

test("cross-store quote scope is forbidden even for valid cashier", async () => {
  const api = createApiHandler({
    authenticator: new FixedAuthenticator(cashier)
  });

  const response = await api.handle({
    method: "POST",
    path: "/v1/sales/quote",
    bodyText: quoteBody({ storeId: "store-other" }),
    requestId: "req-3",
    now: new Date("2026-09-29T01:00:00Z")
  });

  assert.equal(response.statusCode, 403);
  assert.equal(response.body.code, "FORBIDDEN");
});

test("stock worker cannot use sale quote despite valid tenant scope", async () => {
  const api = createApiHandler({
    authenticator: new FixedAuthenticator(stockWorker)
  });

  const response = await api.handle({
    method: "POST",
    path: "/v1/sales/quote",
    bodyText: quoteBody(),
    requestId: "req-4",
    now: new Date("2026-09-29T01:00:00Z")
  });

  assert.equal(response.statusCode, 403);
  assert.equal(response.body.code, "FORBIDDEN");
});

test("invalid JSON and invalid tax fields return stable 400 envelopes", async () => {
  const api = createApiHandler({
    authenticator: new FixedAuthenticator(cashier)
  });

  const invalidJson = await api.handle({
    method: "POST",
    path: "/v1/sales/quote",
    bodyText: "{",
    requestId: "req-5",
    now: new Date("2026-09-29T01:00:00Z")
  });
  assert.equal(invalidJson.statusCode, 400);
  assert.equal(invalidJson.body.code, "INVALID_REQUEST");

  const invalidTax = await api.handle({
    method: "POST",
    path: "/v1/sales/quote",
    bodyText: quoteBody({ taxMode: "unknown" }),
    requestId: "req-6",
    now: new Date("2026-09-29T01:00:00Z")
  });
  assert.equal(invalidTax.statusCode, 400);
});

test("auth failures fail closed with 401 or explicit 503", async () => {
  const rejected = createApiHandler({
    authenticator: new RejectingAuthenticator()
  });
  const unauthenticated = await rejected.handle({
    method: "GET",
    path: "/v1/session",
    requestId: "req-7",
    now: new Date("2026-09-29T01:00:00Z")
  });
  assert.equal(unauthenticated.statusCode, 401);
  assert.equal(unauthenticated.body.code, "UNAUTHENTICATED");

  const unavailable = createApiHandler({
    authenticator: new UnconfiguredRequestAuthenticator()
  });
  const notConfigured = await unavailable.handle({
    method: "GET",
    path: "/v1/session",
    authorizationHeader: "Bearer ignored",
    requestId: "req-8",
    now: new Date("2026-09-29T01:00:00Z")
  });
  assert.equal(notConfigured.statusCode, 503);
  assert.equal(
    notConfigured.body.code,
    "AUTHENTICATION_UNAVAILABLE"
  );
});

test("known resource rejects unsupported method with Allow header", async () => {
  const api = createApiHandler({
    authenticator: new FixedAuthenticator(cashier)
  });

  const response = await api.handle({
    method: "POST",
    path: "/v1/session",
    bodyText: "{}",
    requestId: "req-method",
    now: new Date("2026-09-29T01:00:00Z")
  });

  assert.equal(response.statusCode, 405);
  assert.equal(response.body.code, "METHOD_NOT_ALLOWED");
  assert.equal(response.headers?.allow, "GET");
});

test("unknown route does not invoke protected business logic", async () => {
  const api = createApiHandler({
    authenticator: new FixedAuthenticator(cashier)
  });

  const response = await api.handle({
    method: "GET",
    path: "/v1/unknown",
    requestId: "req-9",
    now: new Date("2026-09-29T01:00:00Z")
  });

  assert.equal(response.statusCode, 404);
  assert.equal(response.body.code, "NOT_FOUND");
});
