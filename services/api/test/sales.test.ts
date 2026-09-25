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
