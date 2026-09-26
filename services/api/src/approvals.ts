export type ApprovalStatus = "pending" | "approved" | "rejected";

export interface ApprovalRequestRecord {
  id: string;
  organizationId: string;
  businessId: string;
  storeId?: string;
  actionType: string;
  entityType: string;
  entityId: string;
  requestedByUserId: string;
  requestedAt: string;
  status: ApprovalStatus;
  actionFingerprint?: string;
  requestedAmountMinor?: number;
  expiresAt?: string;
  resolvedByUserId?: string;
  resolvedAt?: string;
  reason?: string;
}

export interface ApprovalConsumption {
  id: string;
  approvalRequestId: string;
  organizationId: string;
  businessId: string;
  storeId?: string;
  consumedByUserId: string;
  actionFingerprint: string;
  consumedAt: string;
  requestId: string;
}

function required(field: string, value: string): void {
  if (!value.trim()) throw new Error(`${field} is required`);
}

export function validateApprovalRequest(
  request: ApprovalRequestRecord
): void {
  required("id", request.id);
  required("organizationId", request.organizationId);
  required("businessId", request.businessId);
  required("actionType", request.actionType);
  required("entityType", request.entityType);
  required("entityId", request.entityId);
  required("requestedByUserId", request.requestedByUserId);

  if (Number.isNaN(Date.parse(request.requestedAt))) {
    throw new Error("Approval requestedAt must be an ISO date-time");
  }

  if (
    request.requestedAmountMinor !== undefined &&
    (!Number.isSafeInteger(request.requestedAmountMinor) ||
      request.requestedAmountMinor < 0)
  ) {
    throw new Error("Approval amount must be a non-negative safe integer");
  }

  if (request.actionFingerprint !== undefined) {
    required("actionFingerprint", request.actionFingerprint);
    if (request.actionFingerprint.length > 512) {
      throw new Error("Approval fingerprint is too long");
    }
  }

  if (request.expiresAt !== undefined) {
    const expires = Date.parse(request.expiresAt);
    if (
      Number.isNaN(expires) ||
      expires <= Date.parse(request.requestedAt)
    ) {
      throw new Error("Approval expiry must be after request time");
    }
  }

  if (request.status === "pending") {
    if (
      request.resolvedAt !== undefined ||
      request.resolvedByUserId !== undefined
    ) {
      throw new Error("Pending approval cannot already be resolved");
    }
  } else {
    if (
      request.resolvedAt === undefined ||
      request.resolvedByUserId === undefined
    ) {
      throw new Error("Resolved approval requires resolver evidence");
    }
    if (request.resolvedByUserId === request.requestedByUserId) {
      throw new Error("Approval requester cannot self-approve/reject");
    }
  }
}

export function resolveApproval(input: {
  request: ApprovalRequestRecord;
  resolverUserId: string;
  resolverRole: "owner" | "manager" | "cashier" | "stock_worker";
  decision: "approve" | "reject";
  resolvedAt: string;
  reason?: string;
}): ApprovalRequestRecord {
  validateApprovalRequest(input.request);
  required("resolverUserId", input.resolverUserId);

  if (input.request.status !== "pending") {
    throw new Error("Approval request is already resolved");
  }
  if (input.resolverRole !== "owner" && input.resolverRole !== "manager") {
    throw new Error("Role cannot resolve approvals");
  }
  if (input.resolverUserId === input.request.requestedByUserId) {
    throw new Error("Approval requester cannot resolve own request");
  }
  if (Number.isNaN(Date.parse(input.resolvedAt))) {
    throw new Error("resolvedAt must be an ISO date-time");
  }

  const resolvedReason = input.reason?.trim() || input.request.reason;

  return {
    ...input.request,
    status: input.decision === "approve" ? "approved" : "rejected",
    resolvedByUserId: input.resolverUserId,
    resolvedAt: input.resolvedAt,
    ...(resolvedReason === undefined ? {} : { reason: resolvedReason })
  };
}

export function assertApprovalConsumable(input: {
  request: ApprovalRequestRecord;
  fingerprint: string;
  now: Date;
  alreadyConsumed: boolean;
}): void {
  validateApprovalRequest(input.request);
  required("fingerprint", input.fingerprint);

  if (input.request.status !== "approved") {
    throw new Error("Approval is not approved");
  }
  if (input.alreadyConsumed) {
    throw new Error("Approval has already been consumed");
  }
  if (
    input.request.actionFingerprint === undefined ||
    input.request.actionFingerprint !== input.fingerprint
  ) {
    throw new Error("Approval fingerprint does not match action");
  }
  if (
    input.request.expiresAt !== undefined &&
    input.now.getTime() >= Date.parse(input.request.expiresAt)
  ) {
    throw new Error("Approval has expired");
  }
}
