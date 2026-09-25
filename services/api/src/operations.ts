export type EmployeeRole = "owner" | "manager" | "cashier" | "stock_worker";
export type CashMovementType = "deposit" | "withdrawal";
export type ExpensePaymentMethod = "cash" | "upi" | "card" | "bank";

function assertMoney(value: number, field: string, allowZero = false): void {
  const valid = Number.isSafeInteger(value) && (allowZero ? value >= 0 : value > 0);
  if (!valid) {
    throw new Error(`${field} must be ${allowZero ? "non-negative" : "positive"} integer paise`);
  }
}

export interface ShiftCashInput {
  openingCashMinor: number;
  cashSalesMinor: number;
  cashCreditCollectionsMinor: number;
  cashDepositsMinor: number;
  cashWithdrawalsMinor: number;
  cashExpensesMinor: number;
}

export function expectedClosingCashMinor(input: ShiftCashInput): number {
  assertMoney(input.openingCashMinor, "openingCashMinor", true);
  assertMoney(input.cashSalesMinor, "cashSalesMinor", true);
  assertMoney(input.cashCreditCollectionsMinor, "cashCreditCollectionsMinor", true);
  assertMoney(input.cashDepositsMinor, "cashDepositsMinor", true);
  assertMoney(input.cashWithdrawalsMinor, "cashWithdrawalsMinor", true);
  assertMoney(input.cashExpensesMinor, "cashExpensesMinor", true);

  const expected =
    input.openingCashMinor +
    input.cashSalesMinor +
    input.cashCreditCollectionsMinor +
    input.cashDepositsMinor -
    input.cashWithdrawalsMinor -
    input.cashExpensesMinor;

  if (expected < 0) {
    throw new Error("Expected closing cash cannot be negative");
  }
  return expected;
}

export function cashVarianceMinor(
  expectedClosingMinor: number,
  actualClosingMinor: number
): number {
  assertMoney(expectedClosingMinor, "expectedClosingMinor", true);
  assertMoney(actualClosingMinor, "actualClosingMinor", true);
  return actualClosingMinor - expectedClosingMinor;
}

export function requiresVarianceApproval(
  varianceMinor: number,
  thresholdMinor: number
): boolean {
  if (!Number.isSafeInteger(varianceMinor)) {
    throw new Error("varianceMinor must be an integer");
  }
  assertMoney(thresholdMinor, "thresholdMinor", true);
  return Math.abs(varianceMinor) > thresholdMinor;
}

export function validateExpense(input: {
  amountMinor: number;
  category: string;
  paymentMethod: ExpensePaymentMethod;
}): void {
  assertMoney(input.amountMinor, "amountMinor");
  if (!input.category.trim()) {
    throw new Error("Expense category is required");
  }
}
