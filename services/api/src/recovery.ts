import { createHash } from "node:crypto";

export type RecoveryScope = "business" | "store";
export type RecoveryCheckpointStatus =
  | "available"
  | "verified"
  | "invalid"
  | "expired";

export interface RecoveryCheckpointManifest {
  id: string;
  organizationId: string;
  businessId: string;
  scope: RecoveryScope;
  storeId?: string;
  schemaVersion: number;
  createdAt: string;
  contentHash: string;
  encrypted: boolean;
  storageReference: string;
  status: RecoveryCheckpointStatus;
  recordCounts: Readonly<Record<string, number>>;
}

export interface RecoveryAssessment {
  canDryRunRestore: boolean;
  blockers: readonly string[];
  warnings: readonly string[];
}

function requireNonEmpty(field: string, value: string): void {
  if (!value.trim()) {
    throw new Error(`${field} is required`);
  }
}

export function validateRecoveryCheckpoint(
  manifest: RecoveryCheckpointManifest
): void {
  requireNonEmpty("id", manifest.id);
  requireNonEmpty("organizationId", manifest.organizationId);
  requireNonEmpty("businessId", manifest.businessId);
  requireNonEmpty("storageReference", manifest.storageReference);

  if (
    !Number.isSafeInteger(manifest.schemaVersion) ||
    manifest.schemaVersion <= 0
  ) {
    throw new Error("schemaVersion must be a positive safe integer");
  }

  if (Number.isNaN(Date.parse(manifest.createdAt))) {
    throw new Error("createdAt must be an ISO date-time");
  }

  if (!/^[0-9a-f]{64}$/.test(manifest.contentHash)) {
    throw new Error("contentHash must be a lowercase SHA-256 hex digest");
  }

  if (!manifest.encrypted) {
    throw new Error("Recovery checkpoint must be encrypted");
  }

  if (manifest.scope === "store") {
    if (!manifest.storeId?.trim()) {
      throw new Error("Store-scoped recovery checkpoint requires storeId");
    }
  } else if (manifest.storeId !== undefined) {
    throw new Error(
      "Business-scoped recovery checkpoint must not declare storeId"
    );
  }

  for (const [name, count] of Object.entries(manifest.recordCounts)) {
    requireNonEmpty("record count name", name);
    if (!Number.isSafeInteger(count) || count < 0) {
      throw new Error(
        `Recovery record count ${name} must be a non-negative safe integer`
      );
    }
  }
}

export function recoveryContentHash(
  content: Uint8Array
): string {
  return createHash("sha256").update(content).digest("hex");
}

export function verifyRecoveryContent(input: {
  content: Uint8Array;
  expectedHash: string;
}): boolean {
  if (!/^[0-9a-f]{64}$/.test(input.expectedHash)) {
    throw new Error("expectedHash must be a lowercase SHA-256 hex digest");
  }
  return recoveryContentHash(input.content) === input.expectedHash;
}

export function assessRecoveryCheckpoint(input: {
  checkpoint: RecoveryCheckpointManifest;
  targetOrganizationId: string;
  targetBusinessId: string;
  targetStoreId?: string;
  currentSchemaVersion: number;
  unresolvedLocalWrites: number;
  now: Date;
  staleAfterHours?: number;
}): RecoveryAssessment {
  validateRecoveryCheckpoint(input.checkpoint);
  requireNonEmpty("targetOrganizationId", input.targetOrganizationId);
  requireNonEmpty("targetBusinessId", input.targetBusinessId);

  if (
    !Number.isSafeInteger(input.currentSchemaVersion) ||
    input.currentSchemaVersion <= 0
  ) {
    throw new Error("currentSchemaVersion must be a positive safe integer");
  }
  if (
    !Number.isSafeInteger(input.unresolvedLocalWrites) ||
    input.unresolvedLocalWrites < 0
  ) {
    throw new Error("unresolvedLocalWrites must be non-negative");
  }

  const staleAfterHours = input.staleAfterHours ?? 24;
  if (!Number.isFinite(staleAfterHours) || staleAfterHours <= 0) {
    throw new Error("staleAfterHours must be positive");
  }

  const blockers: string[] = [];
  const warnings: string[] = [];
  const checkpoint = input.checkpoint;

  if (checkpoint.organizationId !== input.targetOrganizationId) {
    blockers.push("ORGANIZATION_SCOPE_MISMATCH");
  }
  if (checkpoint.businessId !== input.targetBusinessId) {
    blockers.push("BUSINESS_SCOPE_MISMATCH");
  }

  if (checkpoint.scope === "store") {
    if (!input.targetStoreId?.trim()) {
      blockers.push("TARGET_STORE_REQUIRED");
    } else if (checkpoint.storeId !== input.targetStoreId) {
      blockers.push("STORE_SCOPE_MISMATCH");
    }
  }

  if (
    checkpoint.status === "invalid" ||
    checkpoint.status === "expired"
  ) {
    blockers.push("CHECKPOINT_NOT_RESTORABLE");
  }

  if (checkpoint.schemaVersion > input.currentSchemaVersion) {
    blockers.push("CHECKPOINT_SCHEMA_NEWER_THAN_RUNTIME");
  } else if (checkpoint.schemaVersion < input.currentSchemaVersion) {
    warnings.push("CHECKPOINT_REQUIRES_SCHEMA_MIGRATION");
  }

  if (input.unresolvedLocalWrites > 0) {
    blockers.push("UNRESOLVED_LOCAL_WRITES");
  }

  const ageMs = input.now.getTime() - Date.parse(checkpoint.createdAt);
  if (ageMs < 0) {
    warnings.push("CHECKPOINT_TIMESTAMP_IN_FUTURE");
  } else if (ageMs > staleAfterHours * 60 * 60 * 1000) {
    warnings.push("CHECKPOINT_OLDER_THAN_TARGET_RPO");
  }

  if (checkpoint.status === "available") {
    warnings.push("CHECKPOINT_HASH_NOT_YET_VERIFIED");
  }

  return {
    canDryRunRestore: blockers.length === 0,
    blockers,
    warnings
  };
}
