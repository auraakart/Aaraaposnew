import test from "node:test";
import assert from "node:assert/strict";
import {
  assertApprovalConsumable,
  resolveApproval,
  type ApprovalRequestRecord
} from "../src/approvals.js";

const pending: ApprovalRequestRecord = {
  id: "approval-1",
  organizationId: "org-1",
  businessId: "business-1",
  storeId: "store-1",
  actionType: "refund",
  entityType: "sale",
  entityId: "sale-1",
  requestedByUserId: "cashier-1",
  requestedAt: "2026-09-26T10:00:00Z",
  status: "pending",
  actionFingerprint: "refund|sale-1|line-1:1000|amount:600000",
  requestedAmountMinor: 600000,
  expiresAt: "2026-09-26T12:00:00Z"
};

test("owner or manager can resolve another user's request", () => {
  const approved = resolveApproval({
    request: pending,
    resolverUserId: "manager-1",
    resolverRole: "manager",
    decision: "approve",
    resolvedAt: "2026-09-26T10:05:00Z"
  });

  assert.equal(approved.status, "approved");
  assert.equal(approved.resolvedByUserId, "manager-1");
});

test("self approval is rejected", () => {
  assert.throws(() =>
    resolveApproval({
      request: pending,
      resolverUserId: "cashier-1",
      resolverRole: "owner",
      decision: "approve",
      resolvedAt: "2026-09-26T10:05:00Z"
    })
  );
});

test("cashier cannot resolve approval", () => {
  assert.throws(() =>
    resolveApproval({
      request: pending,
      resolverUserId: "cashier-2",
      resolverRole: "cashier",
      decision: "approve",
      resolvedAt: "2026-09-26T10:05:00Z"
    })
  );
});

test("approved action fingerprint is consumable exactly once", () => {
  const approved = resolveApproval({
    request: pending,
    resolverUserId: "manager-1",
    resolverRole: "manager",
    decision: "approve",
    resolvedAt: "2026-09-26T10:05:00Z"
  });

  assert.doesNotThrow(() =>
    assertApprovalConsumable({
      request: approved,
      fingerprint: pending.actionFingerprint!,
      now: new Date("2026-09-26T10:10:00Z"),
      alreadyConsumed: false
    })
  );

  assert.throws(() =>
    assertApprovalConsumable({
      request: approved,
      fingerprint: pending.actionFingerprint!,
      now: new Date("2026-09-26T10:10:00Z"),
      alreadyConsumed: true
    })
  );
});

test("expired or mismatched approval cannot authorize action", () => {
  const approved = resolveApproval({
    request: pending,
    resolverUserId: "manager-1",
    resolverRole: "manager",
    decision: "approve",
    resolvedAt: "2026-09-26T10:05:00Z"
  });

  assert.throws(() =>
    assertApprovalConsumable({
      request: approved,
      fingerprint: "different",
      now: new Date("2026-09-26T10:10:00Z"),
      alreadyConsumed: false
    })
  );
  assert.throws(() =>
    assertApprovalConsumable({
      request: approved,
      fingerprint: pending.actionFingerprint!,
      now: new Date("2026-09-26T12:00:00Z"),
      alreadyConsumed: false
    })
  );
});
