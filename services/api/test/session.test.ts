import test from "node:test";
import assert from "node:assert/strict";
import {
  assertRemoteAuthMethod,
  principalFromRemoteSession,
  validateRemoteSessionClaims,
  type RemoteSessionClaims
} from "../src/session.js";

const claims: RemoteSessionClaims = {
  sessionId: "session-1",
  subject: "user-1",
  organizationId: "org-1",
  businessIds: ["business-1"],
  storeIds: ["store-1"],
  role: "cashier",
  authMethod: "passwordless",
  issuedAt: "2026-09-28T01:00:00Z",
  expiresAt: "2026-09-28T09:00:00Z"
};

test("valid remote session becomes an authenticated principal", () => {
  assert.deepEqual(
    principalFromRemoteSession(
      claims,
      new Date("2026-09-28T02:00:00Z")
    ),
    {
      userId: "user-1",
      organizationId: "org-1",
      businessIds: ["business-1"],
      storeIds: ["store-1"],
      role: "cashier"
    }
  );
});

test("expired remote session is rejected", () => {
  assert.throws(() =>
    validateRemoteSessionClaims(
      claims,
      new Date("2026-09-28T10:00:00Z")
    )
  );
});

test("remote session lifetime is capped", () => {
  assert.throws(() =>
    validateRemoteSessionClaims(
      {
        ...claims,
        expiresAt: "2026-09-30T09:00:00Z"
      },
      new Date("2026-09-28T02:00:00Z")
    )
  );
});

test("local PIN is never accepted as a remote auth method", () => {
  assert.throws(() => assertRemoteAuthMethod("local_pin"));
  assert.equal(assertRemoteAuthMethod("oidc"), "oidc");
});
