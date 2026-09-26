import test from "node:test";
import assert from "node:assert/strict";
import {
  auditDedupeKey,
  assertSafeAuditMetadata,
  validateAuditEvent,
  type AuditEventInput
} from "../src/audit.js";

const event: AuditEventInput = {
  id: "audit-1",
  organizationId: "org-1",
  businessId: "business-1",
  storeId: "store-1",
  terminalId: "terminal-1",
  actorUserId: "user-1",
  action: "sale.finalized",
  affectedEntityType: "sale",
  affectedEntityId: "sale-1",
  occurredAt: "2026-09-26T03:30:00Z",
  requestId: "request-1",
  outcome: "success",
  metadata: { paymentMethod: "cash", totalMinor: 11800 }
};

test("valid audit events have stable tenant-scoped dedupe keys", () => {
  assert.doesNotThrow(() => validateAuditEvent(event));
  assert.equal(auditDedupeKey(event), "audit:org-1:audit-1");
});

test("audit metadata rejects secrets and card-sensitive keys recursively", () => {
  assert.throws(() =>
    assertSafeAuditMetadata({ nested: { authorizationToken: "secret" } })
  );
  assert.throws(() => assertSafeAuditMetadata({ cvv: "123" }));
});

test("audit timestamps must be parseable", () => {
  assert.throws(() =>
    validateAuditEvent({
      ...event,
      occurredAt: "not-a-date"
    })
  );
});
