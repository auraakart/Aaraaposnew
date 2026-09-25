export type PurchaseOrderStatus =
  | "draft"
  | "ordered"
  | "partially_received"
  | "received"
  | "cancelled";

export type SupplierLedgerEntryType =
  | "purchase_charge"
  | "payment"
  | "purchase_return_credit"
  | "correction_increase"
  | "correction_decrease";

export interface PurchaseLineInput {
  productId: string;
  quantityMilli: number;
  unitCostMinor: number;
  taxMinor?: number;
}

export interface SupplierLedgerEntry {
  id: string;
  supplierId: string;
  type: SupplierLedgerEntryType;
  amountMinor: number;
  occurredAt: string;
  sourceId?: string;
}

function assertPositiveInteger(value: number, field: string): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error(`${field} must be a positive integer`);
  }
}

export function purchaseLineTotalMinor(line: PurchaseLineInput): number {
  assertPositiveInteger(line.quantityMilli, "quantityMilli");
  assertPositiveInteger(line.unitCostMinor, "unitCostMinor");
  const taxMinor = line.taxMinor ?? 0;
  if (!Number.isSafeInteger(taxMinor) || taxMinor < 0) {
    throw new Error("taxMinor must be a non-negative integer");
  }
  const netMinor = Math.floor(
    (line.unitCostMinor * line.quantityMilli + 500) / 1000
  );
  return netMinor + taxMinor;
}

export function purchaseTotalMinor(
  lines: readonly PurchaseLineInput[]
): number {
  if (lines.length === 0) {
    throw new Error("Purchase requires at least one line");
  }
  return lines.reduce((sum, line) => sum + purchaseLineTotalMinor(line), 0);
}

function isIncrease(type: SupplierLedgerEntryType): boolean {
  return (
    type === "purchase_charge" ||
    type === "correction_increase"
  );
}

export function supplierBalanceMinor(
  entries: readonly SupplierLedgerEntry[]
): number {
  const ordered = [...entries].sort((a, b) =>
    a.occurredAt.localeCompare(b.occurredAt)
  );
  let balance = 0;
  for (const entry of ordered) {
    assertPositiveInteger(entry.amountMinor, "supplier amount");
    balance += isIncrease(entry.type) ? entry.amountMinor : -entry.amountMinor;
  }
  return balance;
}

export function validateSupplierPayment(
  balanceMinor: number,
  paymentMinor: number
): void {
  if (!Number.isSafeInteger(balanceMinor) || balanceMinor <= 0) {
    throw new Error("Supplier has no payable balance");
  }
  assertPositiveInteger(paymentMinor, "paymentMinor");
  if (paymentMinor > balanceMinor) {
    throw new Error("Supplier payment cannot exceed payable balance");
  }
}

export function nextOrderStatus(input: {
  orderedMilli: number;
  receivedMilli: number;
  cancelled: boolean;
}): PurchaseOrderStatus {
  if (input.cancelled) return "cancelled";
  assertPositiveInteger(input.orderedMilli, "orderedMilli");
  if (
    !Number.isSafeInteger(input.receivedMilli) ||
    input.receivedMilli < 0 ||
    input.receivedMilli > input.orderedMilli
  ) {
    throw new Error("Invalid received quantity");
  }
  if (input.receivedMilli === 0) return "ordered";
  if (input.receivedMilli === input.orderedMilli) return "received";
  return "partially_received";
}
