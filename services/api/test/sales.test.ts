import test from "node:test";
import assert from "node:assert/strict";
import { cashChangeDue, priceSale, priceSaleLine } from "../src/sales.js";

test("exclusive intra-state tax splits CGST and SGST", () => {
  const line = priceSaleLine({
    productId: "p1",
    name: "Milk",
    unitPriceMinor: 10000,
    quantityMilli: 1000,
    discountMinor: 0,
    taxRateBps: 500,
    taxPriceMode: "exclusive"
  }, "intra_state");

  assert.equal(line.taxableMinor, 10000);
  assert.equal(line.taxMinor, 500);
  assert.equal(line.cgstMinor + line.sgstMinor, 500);
  assert.equal(line.igstMinor, 0);
  assert.equal(line.totalMinor, 10500);
});

test("inclusive tax preserves displayed total", () => {
  const line = priceSaleLine({
    productId: "p2",
    name: "Inclusive item",
    unitPriceMinor: 10500,
    quantityMilli: 1000,
    discountMinor: 0,
    taxRateBps: 500,
    taxPriceMode: "inclusive"
  }, "intra_state");

  assert.equal(line.taxableMinor, 10000);
  assert.equal(line.taxMinor, 500);
  assert.equal(line.totalMinor, 10500);
});

test("weighted quantity uses milli-units without floating point money", () => {
  const line = priceSaleLine({
    productId: "p3",
    name: "Rice",
    unitPriceMinor: 8000,
    quantityMilli: 1500,
    discountMinor: 0,
    taxRateBps: 0,
    taxPriceMode: "exclusive"
  }, "intra_state");

  assert.equal(line.grossMinor, 12000);
  assert.equal(line.totalMinor, 12000);
});

test("sale totals aggregate lines and cash returns change", () => {
  const sale = priceSale([
    {
      productId: "p1",
      name: "Milk",
      unitPriceMinor: 42700,
      quantityMilli: 1000,
      discountMinor: 0,
      taxRateBps: 0,
      taxPriceMode: "exclusive"
    }
  ], "intra_state");

  assert.equal(sale.totalMinor, 42700);
  assert.equal(cashChangeDue(sale.totalMinor, 50000), 7300);
});

test("discount cannot exceed line gross", () => {
  assert.throws(() => priceSaleLine({
    productId: "p",
    name: "Bad discount",
    unitPriceMinor: 1000,
    quantityMilli: 1000,
    discountMinor: 1001,
    taxRateBps: 0,
    taxPriceMode: "exclusive"
  }, "intra_state"));
});


test("partial return prorates tax and total from the original sale line", () => {
  assert.deepEqual(
    priceReturnLine({
      saleLineId: "line-1",
      productId: "p1",
      soldQuantityMilli: 2000,
      alreadyReturnedQuantityMilli: 0,
      requestedReturnQuantityMilli: 1000,
      taxableMinor: 20000,
      cgstMinor: 500,
      sgstMinor: 500,
      igstMinor: 0,
      taxMinor: 1000,
      totalMinor: 21000
    }),
    {
      saleLineId: "line-1",
      productId: "p1",
      quantityMilli: 1000,
      taxableMinor: 10000,
      cgstMinor: 250,
      sgstMinor: 250,
      igstMinor: 0,
      taxMinor: 500,
      totalMinor: 10500
    }
  );
});

test("return cannot exceed remaining refundable quantity", () => {
  assert.throws(() =>
    priceReturnLine({
      saleLineId: "line-1",
      productId: "p1",
      soldQuantityMilli: 2000,
      alreadyReturnedQuantityMilli: 1500,
      requestedReturnQuantityMilli: 1000,
      taxableMinor: 20000,
      cgstMinor: 500,
      sgstMinor: 500,
      igstMinor: 0,
      taxMinor: 1000,
      totalMinor: 21000
    })
  );
});

test("cashier discount above self-approval threshold requires approval", () => {
  assert.equal(
    requiresDiscountApproval({
      lineGrossMinor: 10000,
      discountMinor: 600,
      actorRole: "cashier",
      cashierSelfApprovalLimitBps: 500
    }),
    true
  );
  assert.equal(
    requiresDiscountApproval({
      lineGrossMinor: 10000,
      discountMinor: 600,
      actorRole: "manager"
    }),
    false
  );
});
