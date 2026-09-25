import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import {
  hasProviderCapability,
  nextSyncState,
  providerEventIdempotencyKey,
  resolveReplay,
  syncConflictClass,
  validateWebhookTimestamp,
  verifyWebhookSignature,
  type SyncEnvelope
} from "../src/integrations.js";

const envelope: SyncEnvelope = {
  id: "outbox-1",
  entityType: "sale",
  entityId: "sale-1",
  organizationId: "org-1",
  businessId: "business-1",
  storeId: "store-1",
  terminalId: "terminal-1",
  idempotencyKey: "sale-idempotency-1",
  schemaVersion: 1,
  createdAt: "2026-09-25T10:00:00Z",
  payload: { totalMinor: 10000 }
};

test("identical replay is acknowledged without duplicating the entity", () => {
  assert.deepEqual(
    resolveReplay({
      envelope,
      existingEntityId: "sale-1",
      existingPayloadHash: "hash-a",
      incomingPayloadHash: "hash-a"
    }),
    {
      idempotencyKey: "sale-idempotency-1",
      entityId: "sale-1",
      state: "acknowledged",
      code: "IDEMPOTENT_REPLAY"
    }
  );
});

test("idempotency key collision becomes an explicit conflict", () => {
  const result = resolveReplay({
    envelope,
    existingEntityId: "sale-other",
    existingPayloadHash: "hash-old",
    incomingPayloadHash: "hash-new"
  });
  assert.equal(result.state, "conflict");
  assert.equal(result.code, "IDEMPOTENCY_COLLISION");
});

test("financial and configuration conflicts use different policies", () => {
  assert.equal(syncConflictClass("sale"), "append_only_financial");
  assert.equal(
    syncConflictClass("loyalty_program"),
    "configuration_security"
  );
  assert.equal(syncConflictClass("customer"), "master_data");
});

test("sync lifecycle rejects unsafe state jumps", () => {
  assert.equal(nextSyncState("pending", "send"), "sending");
  assert.equal(nextSyncState("sending", "acknowledge"), "acknowledged");
  assert.equal(nextSyncState("conflict", "retry"), "pending");
  assert.throws(() => nextSyncState("acknowledged", "retry"));
});

test("provider capability is explicit and configured", () => {
  const status = {
    provider: "demo",
    configured: true,
    capabilities: ["payment_charge", "webhook"] as const
  };
  assert.equal(hasProviderCapability(status, "payment_charge"), true);
  assert.equal(hasProviderCapability(status, "payment_refund"), false);
  assert.equal(
    hasProviderCapability(
      { ...status, configured: false },
      "payment_charge"
    ),
    false
  );
});

test("webhook signature is HMAC verified with constant-time compare", () => {
  const payload = JSON.stringify({ id: "evt-1", status: "captured" });
  const secret = "test-secret-123456789";
  const signature = createHmac("sha256", secret)
    .update(payload)
    .digest("hex");

  assert.equal(
    verifyWebhookSignature({ payload, signature, secret }),
    true
  );
  assert.equal(
    verifyWebhookSignature({
      payload,
      signature: "0".repeat(64),
      secret
    }),
    false
  );
});

test("stale webhook timestamps are rejected by the timestamp contract", () => {
  assert.equal(
    validateWebhookTimestamp({
      eventTimestampSeconds: 1000,
      nowSeconds: 1200,
      maxAgeSeconds: 300
    }),
    true
  );
  assert.equal(
    validateWebhookTimestamp({
      eventTimestampSeconds: 1000,
      nowSeconds: 1400,
      maxAgeSeconds: 300
    }),
    false
  );
});

test("provider event IDs create stable dedupe keys", () => {
  assert.equal(
    providerEventIdempotencyKey({
      provider: "example",
      providerEventId: "evt-123"
    }),
    "provider-event:example:evt-123"
  );
});
