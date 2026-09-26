export type TaxClassificationType = "hsn" | "sac" | "other";
export type TaxPriceMode = "inclusive" | "exclusive";
export type TaxRuleStatus = "active" | "retired";

export interface TaxRuleVersion {
  id: string;
  organizationId: string;
  businessId: string;
  ruleKey: string;
  version: number;
  classificationType: TaxClassificationType;
  classificationCode: string;
  rateBps: number;
  priceMode: TaxPriceMode;
  effectiveFrom: string;
  effectiveTo?: string;
  status: TaxRuleStatus;
}

function required(field: string, value: string): void {
  if (!value.trim()) throw new Error(`${field} is required`);
}

export function validateTaxRuleVersion(rule: TaxRuleVersion): void {
  required("id", rule.id);
  required("organizationId", rule.organizationId);
  required("businessId", rule.businessId);
  required("ruleKey", rule.ruleKey);
  required("classificationCode", rule.classificationCode);

  if (!Number.isSafeInteger(rule.version) || rule.version <= 0) {
    throw new Error("Tax rule version must be a positive safe integer");
  }
  if (!Number.isSafeInteger(rule.rateBps) || rule.rateBps < 0 || rule.rateBps > 10000) {
    throw new Error("Tax rate basis points must be between 0 and 10000");
  }
  if (!/^[A-Za-z0-9.-]{2,32}$/.test(rule.classificationCode)) {
    throw new Error("Tax classification code format is invalid");
  }

  const from = Date.parse(rule.effectiveFrom);
  if (Number.isNaN(from)) {
    throw new Error("Tax effectiveFrom must be an ISO date-time");
  }
  if (rule.effectiveTo !== undefined) {
    const to = Date.parse(rule.effectiveTo);
    if (Number.isNaN(to) || to <= from) {
      throw new Error("Tax effectiveTo must be after effectiveFrom");
    }
  }
}

export function resolveEffectiveTaxRule(input: {
  rules: readonly TaxRuleVersion[];
  organizationId: string;
  businessId: string;
  ruleKey: string;
  at: Date;
}): TaxRuleVersion {
  required("organizationId", input.organizationId);
  required("businessId", input.businessId);
  required("ruleKey", input.ruleKey);

  const atMs = input.at.getTime();
  if (Number.isNaN(atMs)) throw new Error("Tax resolution time is invalid");

  const candidates = input.rules.filter((rule) => {
    validateTaxRuleVersion(rule);
    if (
      rule.organizationId !== input.organizationId ||
      rule.businessId !== input.businessId ||
      rule.ruleKey !== input.ruleKey ||
      rule.status !== "active"
    ) {
      return false;
    }

    const from = Date.parse(rule.effectiveFrom);
    const to =
      rule.effectiveTo === undefined
        ? Number.POSITIVE_INFINITY
        : Date.parse(rule.effectiveTo);
    return from <= atMs && atMs < to;
  });

  if (candidates.length === 0) {
    throw new Error("No effective tax rule found");
  }
  if (candidates.length > 1) {
    throw new Error("Overlapping effective tax rules are not allowed");
  }
  return candidates[0]!;
}

export interface TaxSnapshot {
  rateBps: number;
  priceMode: TaxPriceMode;
  classificationType: TaxClassificationType;
  classificationCode: string;
  taxRuleVersionId: string;
}

export function snapshotTaxRule(rule: TaxRuleVersion): TaxSnapshot {
  validateTaxRuleVersion(rule);
  return {
    rateBps: rule.rateBps,
    priceMode: rule.priceMode,
    classificationType: rule.classificationType,
    classificationCode: rule.classificationCode,
    taxRuleVersionId: rule.id
  };
}
