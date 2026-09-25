export type PaymentMethod = "cash" | "upi" | "card";
export type PaymentStatus =
  | "pending"
  | "authorized"
  | "captured"
  | "failed"
  | "cancelled";
export type ReconciliationStatus =
  | "not_applicable"
  | "pending"
  | "matched"
  | "mismatch";

export interface PaymentAllocation {
  method: PaymentMethod;
  amountMinor: number;
  status: PaymentStatus;
  provider?: string;
  providerReference?: string;
}

export interface PaymentProviderRequest {
  paymentId: string;
  amountMinor: number;
  currency: "INR";
  idempotencyKey: string;
  terminalId: string;
  storeId: string;
}

export interface PaymentProviderResult {
  status: PaymentStatus;
  provider: string;
  providerReference?: string;
  message?: string;
}

export interface ExternalPaymentAdapter {
  readonly method: "upi" | "card";
  readonly provider: string;
  isAvailable(): Promise<boolean>;
  initiate(request: PaymentProviderRequest): Promise<PaymentProviderResult>;
  query(providerReference: string): Promise<PaymentProviderResult>;
}

function assertMoney(value: number, field: string): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${field} must be a positive integer number of paise`);
  }
}

export function validateSplitPayment(
  saleTotalMinor: number,
  allocations: readonly PaymentAllocation[]
): void {
  assertMoney(saleTotalMinor, "saleTotalMinor");
  if (allocations.length === 0) {
    throw new Error("At least one payment allocation is required");
  }

  let allocatedMinor = 0;
  for (const allocation of allocations) {
    assertMoney(allocation.amountMinor, "allocation.amountMinor");

    if (
      allocation.method !== "cash" &&
      allocation.status === "captured" &&
      (!allocation.provider || !allocation.providerReference)
    ) {
      throw new Error(
        "Captured external payments require provider and providerReference"
      );
    }

    allocatedMinor += allocation.amountMinor;
  }

  if (allocatedMinor !== saleTotalMinor) {
    throw new Error(
      `Payment allocations must equal sale total: expected ${saleTotalMinor}, got ${allocatedMinor}`
    );
  }
}

export function canFinalizeSale(
  saleTotalMinor: number,
  allocations: readonly PaymentAllocation[]
): boolean {
  try {
    validateSplitPayment(saleTotalMinor, allocations);
  } catch {
    return false;
  }

  return allocations.every((allocation) => allocation.status === "captured");
}

export interface ReconciliationInput {
  expectedMinor: number;
  providerReportedMinor: number;
  localStatus: PaymentStatus;
  providerStatus: PaymentStatus;
}

export function reconcilePayment(
  input: ReconciliationInput
): ReconciliationStatus {
  assertMoney(input.expectedMinor, "expectedMinor");
  assertMoney(input.providerReportedMinor, "providerReportedMinor");

  if (
    input.expectedMinor === input.providerReportedMinor &&
    input.localStatus === "captured" &&
    input.providerStatus === "captured"
  ) {
    return "matched";
  }

  return "mismatch";
}

export function sanitizedPaymentAuditDetails(
  allocation: PaymentAllocation
): Readonly<Record<string, string | number>> {
  const details: Record<string, string | number> = {
    method: allocation.method,
    amountMinor: allocation.amountMinor,
    status: allocation.status
  };
  if (allocation.provider) {
    details.provider = allocation.provider;
  }
  if (allocation.providerReference) {
    details.providerReference = allocation.providerReference;
  }
  return details;
}
