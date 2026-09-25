import { createHmac, timingSafeEqual } from "node:crypto";

export type SyncState =
  | "pending"
  | "sending"
  | "acknowledged"
  | "conflict"
  | "rejected";

export type SyncConflictClass =
  | "append_only_financial"
  | "inventory_movement"
  | "master_data"
  | "configuration_security";

export interface SyncEnvelope<T = unknown> {
  id: string;
  entityType: string;
  entityId: string;
  organizationId: string;
  businessId: string;
  storeId: string;
  terminalId: string;
  idempotencyKey: string;
  schemaVersion: number;
  createdAt: string;
  payload: T;
}

export interface SyncAcknowledgement {
  idempotencyKey: string;
  entityId: string;
  state: Exclude<SyncState, "pending" | "sending">;
  serverVersion?: number;
  code?: string;
  message?: string;
}

const appendOnlyFinancialTypes = new Set([
  "sale",
  "sale_return",
  "payment",
  "refund",
  "customer_credit_entry",
  "customer_loyalty_entry",
  "promotion_redemption",
  "expense",
  "purchase_receipt",
  "supplier_ledger_entry"
]);

const inventoryMovementTypes = new Set([
  "stock_movement",
  "store_transfer"
]);

const configurationTypes = new Set([
  "loyalty_program",
  "promotion",
  "tax_configuration",
  "employee_role",
  "store_access"
]);

function requireNonEmpty(field: string, value: string): void {
  if (value.trim().length === 0) {
    throw new Error(`${field} is required`);
  }
}

export function validateSyncEnvelope(envelope: SyncEnvelope): void {
  for (const [field, value] of Object.entries({
    id: envelope.id,
    entityType: envelope.entityType,
    entityId: envelope.entityId,
    organizationId: envelope.organizationId,
    businessId: envelope.businessId,
    storeId: envelope.storeId,
    terminalId: envelope.terminalId,
    idempotencyKey: envelope.idempotencyKey,
    createdAt: envelope.createdAt
  })) {
    requireNonEmpty(field, value);
  }

  if (
    !Number.isSafeInteger(envelope.schemaVersion) ||
    envelope.schemaVersion <= 0
  ) {
    throw new Error("schemaVersion must be a positive safe integer");
  }

  const createdAt = Date.parse(envelope.createdAt);
  if (Number.isNaN(createdAt)) {
    throw new Error("createdAt must be an ISO date-time");
  }

  if (
    typeof envelope.payload !== "object" ||
    envelope.payload === null ||
    Array.isArray(envelope.payload)
  ) {
    throw new Error("payload must be an object");
  }
}

export function syncConflictClass(entityType: string): SyncConflictClass {
  if (appendOnlyFinancialTypes.has(entityType)) {
    return "append_only_financial";
  }
  if (inventoryMovementTypes.has(entityType)) {
    return "inventory_movement";
  }
  if (configurationTypes.has(entityType)) {
    return "configuration_security";
  }
  return "master_data";
}

export function resolveReplay(input: {
  envelope: SyncEnvelope;
  existingEntityId?: string;
  existingPayloadHash?: string;
  incomingPayloadHash: string;
}): SyncAcknowledgement {
  validateSyncEnvelope(input.envelope);
  requireNonEmpty("incomingPayloadHash", input.incomingPayloadHash);

  if (input.existingEntityId === undefined) {
    return {
      idempotencyKey: input.envelope.idempotencyKey,
      entityId: input.envelope.entityId,
      state: "acknowledged"
    };
  }

  if (
    input.existingEntityId === input.envelope.entityId &&
    input.existingPayloadHash === input.incomingPayloadHash
  ) {
    return {
      idempotencyKey: input.envelope.idempotencyKey,
      entityId: input.existingEntityId,
      state: "acknowledged",
      code: "IDEMPOTENT_REPLAY"
    };
  }

  return {
    idempotencyKey: input.envelope.idempotencyKey,
    entityId: input.existingEntityId,
    state: "conflict",
    code: "IDEMPOTENCY_COLLISION",
    message: "The idempotency key was already used for different content."
  };
}

export function nextSyncState(
  current: SyncState,
  event:
    | "send"
    | "acknowledge"
    | "conflict"
    | "reject"
    | "retry"
): SyncState {
  if (current === "pending" && event === "send") return "sending";
  if (current === "sending" && event === "acknowledge") return "acknowledged";
  if (current === "sending" && event === "conflict") return "conflict";
  if (current === "sending" && event === "reject") return "rejected";
  if (
    (current === "sending" ||
      current === "conflict" ||
      current === "rejected") &&
    event === "retry"
  ) {
    return "pending";
  }
  throw new Error(`Invalid sync transition: ${current} -> ${event}`);
}

export type IntegrationCapability =
  | "payment_charge"
  | "payment_refund"
  | "payment_query"
  | "webhook"
  | "message_send"
  | "tax_submit"
  | "accounting_export";

export interface ProviderCapabilityStatus {
  provider: string;
  configured: boolean;
  capabilities: readonly IntegrationCapability[];
}

export function hasProviderCapability(
  status: ProviderCapabilityStatus,
  capability: IntegrationCapability
): boolean {
  return status.configured && status.capabilities.includes(capability);
}

function normalizeSignature(signature: string): string {
  const trimmed = signature.trim().toLowerCase();
  return trimmed.startsWith("sha256=") ? trimmed.slice(7) : trimmed;
}

export function verifyWebhookSignature(input: {
  payload: string | Buffer;
  signature: string;
  secret: string;
}): boolean {
  if (input.secret.length < 16) {
    throw new Error("Webhook secret must be at least 16 characters");
  }

  const expectedHex = createHmac("sha256", input.secret)
    .update(input.payload)
    .digest("hex");
  const providedHex = normalizeSignature(input.signature);

  if (!/^[0-9a-f]{64}$/.test(providedHex)) {
    return false;
  }

  const expected = Buffer.from(expectedHex, "hex");
  const provided = Buffer.from(providedHex, "hex");
  return (
    expected.length === provided.length &&
    timingSafeEqual(expected, provided)
  );
}

export function validateWebhookTimestamp(input: {
  eventTimestampSeconds: number;
  nowSeconds: number;
  maxAgeSeconds?: number;
}): boolean {
  const maxAge = input.maxAgeSeconds ?? 300;
  if (
    !Number.isSafeInteger(input.eventTimestampSeconds) ||
    !Number.isSafeInteger(input.nowSeconds) ||
    !Number.isSafeInteger(maxAge) ||
    maxAge <= 0
  ) {
    throw new Error("Invalid webhook timestamp input");
  }
  const age = Math.abs(input.nowSeconds - input.eventTimestampSeconds);
  return age <= maxAge;
}

export interface ProviderEventIdentity {
  provider: string;
  providerEventId: string;
  providerReference?: string;
}

export function providerEventIdempotencyKey(
  identity: ProviderEventIdentity
): string {
  requireNonEmpty("provider", identity.provider);
  requireNonEmpty("providerEventId", identity.providerEventId);
  return `provider-event:${identity.provider}:${identity.providerEventId}`;
}
