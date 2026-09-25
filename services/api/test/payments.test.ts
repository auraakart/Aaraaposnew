import test from "node:test";
import assert from "node:assert/strict";
import {
  canFinalizeSale,
  reconcilePayment,
  sanitizedPaymentAuditDetails,
  validateSplitPayment
} from "../src/payments.js";

test("split payment must equal the sale total exactly", () => {
  assert.doesNotThrow(() =>
    validateSplitPayment(10000, [
      { method: "cash", amountMinor: 4000, status: "captured" },
      {
        method: "upi",
        amountMinor: 6000,
        status: "captured",
        provider: "example-provider",
        providerReference: "upi-ref-1"
      }
    ])
  );

  assert.throws(() =>
    validateSplitPayment(10000, [
      { method: "cash", amountMinor: 4000, status: "captured" },
      {
        method: "upi",
        amountMinor: 5000,
        status: "captured",
        provider: "example-provider",
        providerReference: "upi-ref-2"
      }
    ])
  );
});

test("customer credit is a valid non-provider settlement", () => {
  assert.doesNotThrow(() =>
    validateSplitPayment(85000, [
      {
        method: "customer_credit",
        amountMinor: 85000,
        status: "captured"
      }
    ])
  );
});

test("captured UPI/card requires provider evidence", () => {
  assert.throws(() =>
    validateSplitPayment(5000, [
      { method: "upi", amountMinor: 5000, status: "captured" }
    ])
  );
});

test("sale finalization requires every allocation captured", () => {
  assert.equal(
    canFinalizeSale(10000, [
      { method: "cash", amountMinor: 5000, status: "captured" },
      {
        method: "card",
        amountMinor: 5000,
        status: "authorized",
        provider: "example-provider",
        providerReference: "card-ref-1"
      }
    ]),
    false
  );
});

test("reconciliation matches amount and captured state", () => {
  assert.equal(
    reconcilePayment({
      expectedMinor: 42700,
      providerReportedMinor: 42700,
      localStatus: "captured",
      providerStatus: "captured"
    }),
    "matched"
  );

  assert.equal(
    reconcilePayment({
      expectedMinor: 42700,
      providerReportedMinor: 42000,
      localStatus: "captured",
      providerStatus: "captured"
    }),
    "mismatch"
  );
});

test("audit projection contains no card credential fields", () => {
  const details = sanitizedPaymentAuditDetails({
    method: "card",
    amountMinor: 5000,
    status: "captured",
    provider: "example-provider",
    providerReference: "safe-reference"
  });

  assert.deepEqual(Object.keys(details).sort(), [
    "amountMinor",
    "method",
    "provider",
    "providerReference",
    "status"
  ]);
});
