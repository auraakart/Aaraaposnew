import test from "node:test";
import assert from "node:assert/strict";
import {
  resolveEffectiveTaxRule,
  snapshotTaxRule,
  type TaxRuleVersion
} from "../src/tax.js";

const base: TaxRuleVersion = {
  id: "tax-rule-v1",
  organizationId: "org-1",
  businessId: "business-1",
  ruleKey: "milk-tax",
  version: 1,
  classificationType: "hsn",
  classificationCode: "0401",
  rateBps: 500,
  priceMode: "inclusive",
  effectiveFrom: "2026-01-01T00:00:00Z",
  effectiveTo: "2027-01-01T00:00:00Z",
  status: "active"
};

test("resolves the single effective version at transaction time", () => {
  const resolved = resolveEffectiveTaxRule({
    rules: [
      { ...base, status: "retired" },
      { ...base, id: "tax-rule-v2", version: 2, status: "active" }
    ],
    organizationId: "org-1",
    businessId: "business-1",
    ruleKey: "milk-tax",
    at: new Date("2026-09-26T10:00:00Z")
  });

  assert.equal(resolved.id, "tax-rule-v2");
});

test("overlapping active versions are rejected", () => {
  assert.throws(() =>
    resolveEffectiveTaxRule({
      rules: [
        base,
        { ...base, id: "tax-rule-overlap", version: 2 }
      ],
      organizationId: "org-1",
      businessId: "business-1",
      ruleKey: "milk-tax",
      at: new Date("2026-09-26T10:00:00Z")
    })
  );
});

test("tax snapshot preserves applied rule evidence", () => {
  assert.deepEqual(snapshotTaxRule(base), {
    rateBps: 500,
    priceMode: "inclusive",
    classificationType: "hsn",
    classificationCode: "0401",
    taxRuleVersionId: "tax-rule-v1"
  });
});

test("cross-business rules are never selected", () => {
  assert.throws(() =>
    resolveEffectiveTaxRule({
      rules: [base],
      organizationId: "org-1",
      businessId: "business-other",
      ruleKey: "milk-tax",
      at: new Date("2026-09-26T10:00:00Z")
    })
  );
});

test("rule rates remain configurable rather than hard-coded", () => {
  const zeroRate = { ...base, id: "zero", rateBps: 0 };
  const highRate = { ...base, id: "high", rateBps: 2800 };

  assert.equal(snapshotTaxRule(zeroRate).rateBps, 0);
  assert.equal(snapshotTaxRule(highRate).rateBps, 2800);
});
