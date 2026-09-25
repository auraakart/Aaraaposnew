import test from "node:test";
import assert from "node:assert/strict";
import {
  creditBalanceMinor,
  customerCreditSummary,
  type CustomerCreditEntry
} from "../src/customers.js";

const entries: CustomerCreditEntry[] = [
  {
    id: "c1",
    customerId: "customer-1",
    type: "charge",
    amountMinor: 85000,
    occurredAt: "2026-09-01T10:00:00Z",
    dueDate: "2026-09-10",
    saleId: "sale-1"
  },
  {
    id: "p1",
    customerId: "customer-1",
    type: "payment",
    amountMinor: 30000,
    occurredAt: "2026-09-15T10:00:00Z"
  }
];

test("partial collection reduces customer balance without changing history", () => {
  assert.equal(creditBalanceMinor(entries), 55000);
});

test("summary identifies outstanding overdue credit", () => {
  assert.deepEqual(customerCreditSummary(entries, "2026-09-25"), {
    balanceMinor: 55000,
    overdueMinor: 55000,
    oldestOutstandingAt: "2026-09-01T10:00:00Z"
  });
});

test("over-collection is rejected", () => {
  assert.throws(() =>
    creditBalanceMinor([
      ...entries,
      {
        id: "p2",
        customerId: "customer-1",
        type: "payment",
        amountMinor: 60000,
        occurredAt: "2026-09-20T10:00:00Z"
      }
    ])
  );
});
