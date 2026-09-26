export type AuditOutcome = "success" | "denied" | "failed";

export interface AuditEventInput {
  id: string;
  organizationId: string;
  businessId: string;
  storeId: string;
  terminalId?: string;
  actorUserId: string;
  action: string;
  affectedEntityType: string;
  affectedEntityId: string;
  occurredAt: string;
  requestId: string;
  outcome: AuditOutcome;
  metadata?: Readonly<Record<string, unknown>>;
}

const sensitiveKeyPattern =
  /(password|secret|token|authorization|cvv|card_number|pan_number)/i;

export function validateAuditEvent(input: AuditEventInput): void {
  const required = {
    id: input.id,
    organizationId: input.organizationId,
    businessId: input.businessId,
    storeId: input.storeId,
    actorUserId: input.actorUserId,
    action: input.action,
    affectedEntityType: input.affectedEntityType,
    affectedEntityId: input.affectedEntityId,
    requestId: input.requestId
  };

  for (const [field, value] of Object.entries(required)) {
    if (!value.trim()) throw new Error(`${field} is required`);
  }

  if (Number.isNaN(Date.parse(input.occurredAt))) {
    throw new Error("Audit occurredAt must be an ISO date-time");
  }

  assertSafeAuditMetadata(input.metadata ?? {});
}

export function assertSafeAuditMetadata(
  metadata: Readonly<Record<string, unknown>>
): void {
  for (const [key, value] of Object.entries(metadata)) {
    if (sensitiveKeyPattern.test(key)) {
      throw new Error(`Sensitive audit metadata key is not allowed: ${key}`);
    }

    if (
      value !== null &&
      typeof value === "object" &&
      !Array.isArray(value)
    ) {
      assertSafeAuditMetadata(value as Readonly<Record<string, unknown>>);
    }
  }
}

export function auditDedupeKey(input: AuditEventInput): string {
  validateAuditEvent(input);
  return `audit:${input.organizationId}:${input.id}`;
}
