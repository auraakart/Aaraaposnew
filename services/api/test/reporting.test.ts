import test from "node:test";
import assert from "node:assert/strict";
import { buildPeriodMetrics, qualityIssueSummary } from "../src/reporting.js";

test("profit is shown only with complete cost coverage", () => {
  assert.deepEqual(
    buildPeriodMetrics({
      salesMinor: 100000,
      billCount: 10,
      moneyReceivedMinor: 90000,
      moneyDueMinor: 10000,
      expensesMinor: 10000,
      estimatedCostMinor: 60000,
      costCoveredSalesMinor: 100000
    }),
    {
      salesMinor: 100000,
      billCount: 10,
      moneyReceivedMinor: 90000,
      moneyDueMinor: 10000,
      expensesMinor: 10000,
      estimatedProfitMinor: 30000,
      costCoverageBps: 10000
    }
  );
});

test("partial cost coverage does not fabricate profit", () => {
  assert.deepEqual(
    buildPeriodMetrics({
      salesMinor: 100000,
      billCount: 10,
      moneyReceivedMinor: 90000,
      moneyDueMinor: 10000,
      expensesMinor: 10000,
      estimatedCostMinor: 30000,
      costCoveredSalesMinor: 50000
    }),
    {
      salesMinor: 100000,
      billCount: 10,
      moneyReceivedMinor: 90000,
      moneyDueMinor: 10000,
      expensesMinor: 10000,
      costCoverageBps: 5000
    }
  );
});

test("quality issue summary preserves severity", () => {
  assert.deepEqual(
    qualityIssueSummary([
      { type: "missing_price", message: "Missing price", severity: "critical" },
      { type: "negative_stock", message: "Negative stock", severity: "warning" },
      { type: "duplicate_customer", message: "Duplicate customer", severity: "warning" }
    ]),
    { info: 0, warning: 2, critical: 1 }
  );
});
