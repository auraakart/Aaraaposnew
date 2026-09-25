import test from "node:test";
import assert from "node:assert/strict";
import {
  nextOrderStatus,
  purchaseTotalMinor,
  supplierBalanceMinor
} from "../src/purchases.js";

test("purchase totals use milli-units and integer money", () => {
  assert.equal(
    purchaseTotalMinor([
      {
        productId: "rice",
        quantityMilli: 1500,
        unitCostMinor: 8000,
        taxMinor: 600
      }
    ]),
    12600
  );
});

test("supplier balance derives from charges returns and payments", () => {
  assert.equal(
    supplierBalanceMinor([
      {
        id: "charge",
        supplierId: "s1",
        type: "purchase_charge",
        amountMinor: 100000,
        occurredAt: "2026-09-01T10:00:00Z"
      },
      {
        id: "return",
        supplierId: "s1",
        type: "purchase_return_credit",
        amountMinor: 20000,
        occurredAt: "2026-09-02T10:00:00Z"
      },
      {
        id: "payment",
        supplierId: "s1",
        type: "payment",
        amountMinor: 30000,
        occurredAt: "2026-09-03T10:00:00Z"
      }
    ]),
    50000
  );
});

test("supplier over-payment is rejected", () => {
  assert.throws(() =>
    supplierBalanceMinor([
      {
        id: "payment",
        supplierId: "s1",
        type: "payment",
        amountMinor: 100,
        occurredAt: "2026-09-01T10:00:00Z"
      }
    ])
  );
});

test("purchase order state tracks partial and full receipt", () => {
  assert.equal(
    nextOrderStatus({ orderedMilli: 10000, receivedMilli: 0, cancelled: false }),
    "ordered"
  );
  assert.equal(
    nextOrderStatus({ orderedMilli: 10000, receivedMilli: 4000, cancelled: false }),
    "partially_received"
  );
  assert.equal(
    nextOrderStatus({ orderedMilli: 10000, receivedMilli: 10000, cancelled: false }),
    "received"
  );
});
