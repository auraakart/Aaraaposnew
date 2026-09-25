import test from "node:test";
import assert from "node:assert/strict";
import {
  classifySalesChange,
  purchaseSuggestion,
  UnconfiguredAiExplanationAdapter,
  validateInsight
} from "../src/ai.js";

test("every insight requires evidence", () => {
  assert.throws(() =>
    validateInsight({
      id: "i1",
      type: "sales",
      classification: "fact",
      title: "Sales",
      message: "Sales were ₹1,000",
      evidence: [],
      generatedBy: "deterministic",
      generatedAt: "2026-09-25T10:00:00Z"
    })
  );
});

test("purchase suggestion exposes calculation rather than guarantee", () => {
  assert.deepEqual(
    purchaseSuggestion({
      onHandMilli: 2000,
      averageDailySoldMilli: 1000,
      targetCoverageDays: 7
    }),
    { suggestedOrderMilli: 5000, daysOfCover: 2 }
  );
});

test("sales comparison uses a materiality threshold", () => {
  assert.equal(
    classifySalesChange({
      currentMinor: 90000,
      comparisonMinor: 100000
    }),
    "lower"
  );
  assert.equal(
    classifySalesChange({
      currentMinor: 98000,
      comparisonMinor: 100000
    }),
    "similar"
  );
});

test("external AI adapter is explicitly optional", async () => {
  const adapter = new UnconfiguredAiExplanationAdapter();
  assert.equal(await adapter.isAvailable(), false);
  await assert.rejects(() =>
    adapter.explain({
      question: "How were sales?",
      facts: { salesMinor: 100000 },
      evidence: [{ metric: "salesMinor", value: 100000, sourceType: "sale" }]
    })
  );
});
