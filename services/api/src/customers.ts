export type CommunicationConsent = "unknown" | "opted_in" | "opted_out";
export type CreditEntryType =
  | "charge"
  | "payment"
  | "correction_increase"
  | "correction_decrease";

export interface CustomerCreditEntry {
  id: string;
  customerId: string;
  type: CreditEntryType;
  amountMinor: number;
  occurredAt: string;
  dueDate?: string;
  saleId?: string;
}

export interface CustomerCreditSummary {
  balanceMinor: number;
  overdueMinor: number;
  oldestOutstandingAt?: string;
}

function assertMoney(value: number): void {
  if (!Number.isSafeInteger(value) || value <= 0) {
    throw new Error("Credit amount must be a positive integer number of paise");
  }
}

export function validateCreditEntry(entry: CustomerCreditEntry): void {
  assertMoney(entry.amountMinor);
  if (entry.type === "charge" && !entry.saleId) {
    throw new Error("Credit sale charge requires saleId");
  }
}

function isIncrease(type: CreditEntryType): boolean {
  return type === "charge" || type === "correction_increase";
}

export function creditBalanceMinor(
  entries: readonly CustomerCreditEntry[]
): number {
  let balance = 0;
  for (const entry of entries) {
    validateCreditEntry(entry);
    balance += isIncrease(entry.type) ? entry.amountMinor : -entry.amountMinor;
    if (balance < 0) {
      throw new Error("Customer credit cannot be over-collected");
    }
  }
  return balance;
}

export function customerCreditSummary(
  entries: readonly CustomerCreditEntry[],
  asOfDate: string
): CustomerCreditSummary {
  const ordered = [...entries].sort((a, b) =>
    a.occurredAt.localeCompare(b.occurredAt)
  );

  const open: Array<{
    remainingMinor: number;
    occurredAt: string;
    dueDate?: string;
  }> = [];

  for (const entry of ordered) {
    validateCreditEntry(entry);
    if (isIncrease(entry.type)) {
      const item: {
        remainingMinor: number;
        occurredAt: string;
        dueDate?: string;
      } = {
        remainingMinor: entry.amountMinor,
        occurredAt: entry.occurredAt
      };
      if (entry.dueDate !== undefined) {
        item.dueDate = entry.dueDate;
      }
      open.push(item);
      continue;
    }

    let remainingPayment = entry.amountMinor;
    for (const item of open) {
      if (remainingPayment === 0) break;
      const applied = Math.min(item.remainingMinor, remainingPayment);
      item.remainingMinor -= applied;
      remainingPayment -= applied;
    }
    if (remainingPayment > 0) {
      throw new Error("Customer credit cannot be over-collected");
    }
  }

  const outstanding = open.filter((item) => item.remainingMinor > 0);
  const balanceMinor = outstanding.reduce(
    (sum, item) => sum + item.remainingMinor,
    0
  );
  const overdueMinor = outstanding
    .filter((item) => item.dueDate !== undefined && item.dueDate < asOfDate)
    .reduce((sum, item) => sum + item.remainingMinor, 0);

  const oldest = outstanding[0]?.occurredAt;
  return oldest === undefined
    ? { balanceMinor, overdueMinor }
    : { balanceMinor, overdueMinor, oldestOutstandingAt: oldest };
}
