import test from "node:test";
import assert from "node:assert/strict";
import {
  assessRecoveryCheckpoint,
  recoveryContentHash,
  verifyRecoveryContent,
  type RecoveryCheckpointManifest
} from "../src/recovery.js";

const payload = new TextEncoder().encode("encrypted-backup-fixture");
const contentHash = recoveryContentHash(payload);

const checkpoint: RecoveryCheckpointManifest = {
  id: "checkpoint-1",
  organizationId: "org-1",
  businessId: "business-1",
  scope: "store",
  storeId: "store-1",
  schemaVersion: 12,
  createdAt: "2026-09-26T10:00:00Z",
  contentHash,
  encrypted: true,
  storageReference: "backup-object:checkpoint-1",
  status: "verified",
  recordCounts: {
    sales: 10,
    payments: 10,
    stockMovements: 30
  }
};

test("checkpoint content hash verifies exact bytes only", () => {
  assert.equal(
    verifyRecoveryContent({ content: payload, expectedHash: contentHash }),
    true
  );
  assert.equal(
    verifyRecoveryContent({
      content: new TextEncoder().encode("different"),
      expectedHash: contentHash
    }),
    false
  );
});

test("matching verified checkpoint may proceed to dry-run assessment", () => {
  assert.deepEqual(
    assessRecoveryCheckpoint({
      checkpoint,
      targetOrganizationId: "org-1",
      targetBusinessId: "business-1",
      targetStoreId: "store-1",
      currentSchemaVersion: 12,
      unresolvedLocalWrites: 0,
      now: new Date("2026-09-26T11:00:00Z")
    }),
    {
      canDryRunRestore: true,
      blockers: [],
      warnings: []
    }
  );
});

test("cross-tenant or cross-store checkpoint is blocked", () => {
  const assessment = assessRecoveryCheckpoint({
    checkpoint,
    targetOrganizationId: "org-other",
    targetBusinessId: "business-1",
    targetStoreId: "store-other",
    currentSchemaVersion: 12,
    unresolvedLocalWrites: 0,
    now: new Date("2026-09-26T11:00:00Z")
  });

  assert.equal(assessment.canDryRunRestore, false);
  assert.deepEqual(assessment.blockers, [
    "ORGANIZATION_SCOPE_MISMATCH",
    "STORE_SCOPE_MISMATCH"
  ]);
});

test("unresolved local writes block replacement or restore", () => {
  const assessment = assessRecoveryCheckpoint({
    checkpoint,
    targetOrganizationId: "org-1",
    targetBusinessId: "business-1",
    targetStoreId: "store-1",
    currentSchemaVersion: 12,
    unresolvedLocalWrites: 3,
    now: new Date("2026-09-26T11:00:00Z")
  });

  assert.equal(assessment.canDryRunRestore, false);
  assert.deepEqual(assessment.blockers, ["UNRESOLVED_LOCAL_WRITES"]);
});

test("older checkpoint warns for migration and RPO age", () => {
  const older = {
    ...checkpoint,
    schemaVersion: 11,
    status: "available" as const,
    createdAt: "2026-09-24T10:00:00Z"
  };

  const assessment = assessRecoveryCheckpoint({
    checkpoint: older,
    targetOrganizationId: "org-1",
    targetBusinessId: "business-1",
    targetStoreId: "store-1",
    currentSchemaVersion: 12,
    unresolvedLocalWrites: 0,
    now: new Date("2026-09-26T11:00:00Z"),
    staleAfterHours: 24
  });

  assert.equal(assessment.canDryRunRestore, true);
  assert.deepEqual(assessment.warnings, [
    "CHECKPOINT_REQUIRES_SCHEMA_MIGRATION",
    "CHECKPOINT_OLDER_THAN_TARGET_RPO",
    "CHECKPOINT_HASH_NOT_YET_VERIFIED"
  ]);
});

test("unencrypted checkpoint is rejected before assessment", () => {
  assert.throws(() =>
    assessRecoveryCheckpoint({
      checkpoint: { ...checkpoint, encrypted: false },
      targetOrganizationId: "org-1",
      targetBusinessId: "business-1",
      targetStoreId: "store-1",
      currentSchemaVersion: 12,
      unresolvedLocalWrites: 0,
      now: new Date("2026-09-26T11:00:00Z")
    })
  );
});
