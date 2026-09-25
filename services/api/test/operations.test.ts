import test from "node:test";
import assert from "node:assert/strict";
import {
  cashVarianceMinor,
  expectedClosingCashMinor,
  requiresVarianceApproval,
  validateExpense
} from "../src/operations.js";

test("expected closing cash includes sales collections deposits expenses and withdrawals", () => {
  assert.equal(
    expectedClosingCashMinor({
      openingCashMinor: 50000,
      cashSalesMinor: 100000,
      cashCreditCollectionsMinor: 20000,
      cashDepositsMinor: 5000,
      cashWithdrawalsMinor: 10000,
      cashExpensesMinor: 15000
    }),
    150000
  );
});

test("cash variance preserves shortages and excesses", () => {
  assert.equal(cashVarianceMinor(150000, 149000), -1000);
  assert.equal(cashVarianceMinor(150000, 151000), 1000);
});

test("variance approval uses absolute threshold", () => {
  assert.equal(requiresVarianceApproval(-1000, 500), true);
  assert.equal(requiresVarianceApproval(400, 500), false);
});

test("expense requires positive money and a category", () => {
  assert.doesNotThrow(() =>
    validateExpense({
      amountMinor: 50000,
      category: "Electricity",
      paymentMethod: "cash"
    })
  );
  assert.throws(() =>
    validateExpense({
      amountMinor: 0,
      category: "Electricity",
      paymentMethod: "cash"
    })
  );
});
