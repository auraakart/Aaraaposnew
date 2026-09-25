export interface PeriodMetricsInput {
  salesMinor: number;
  billCount: number;
  moneyReceivedMinor: number;
  moneyDueMinor: number;
  expensesMinor: number;
  refundsMinor: number;
  estimatedCostMinor?: number;
  costCoveredSalesMinor?: number;
}

export interface PeriodMetrics {
  salesMinor: number;
  billCount: number;
  moneyReceivedMinor: number;
  moneyDueMinor: number;
  expensesMinor: number;
  refundsMinor: number;
  estimatedProfitMinor?: number;
  costCoverageBps: number;
}

function assertNonNegativeInteger(value: number, field: string): void {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${field} must be a non-negative integer`);
  }
}

export function buildPeriodMetrics(
  input: PeriodMetricsInput
): PeriodMetrics {
  assertNonNegativeInteger(input.salesMinor, "salesMinor");
  assertNonNegativeInteger(input.billCount, "billCount");
  assertNonNegativeInteger(input.moneyReceivedMinor, "moneyReceivedMinor");
  assertNonNegativeInteger(input.moneyDueMinor, "moneyDueMinor");
  assertNonNegativeInteger(input.expensesMinor, "expensesMinor");
  assertNonNegativeInteger(input.refundsMinor, "refundsMinor");

  const covered = input.costCoveredSalesMinor ?? 0;
  assertNonNegativeInteger(covered, "costCoveredSalesMinor");
  if (covered > input.salesMinor) {
    throw new Error("costCoveredSalesMinor cannot exceed salesMinor");
  }

  const costCoverageBps =
    input.salesMinor === 0
      ? 10000
      : Math.floor((covered * 10000) / input.salesMinor);

  const base: PeriodMetrics = {
    salesMinor: input.salesMinor,
    billCount: input.billCount,
    moneyReceivedMinor: input.moneyReceivedMinor,
    moneyDueMinor: input.moneyDueMinor,
    expensesMinor: input.expensesMinor,
    refundsMinor: input.refundsMinor,
    costCoverageBps
  };

  if (
    input.estimatedCostMinor !== undefined &&
    covered === input.salesMinor &&
    input.refundsMinor === 0
  ) {
    assertNonNegativeInteger(input.estimatedCostMinor, "estimatedCostMinor");
    return {
      ...base,
      estimatedProfitMinor:
        input.salesMinor - input.estimatedCostMinor - input.expensesMinor
    };
  }

  return base;
}

export type DataQualityIssueType =
  | "duplicate_product"
  | "missing_price"
  | "negative_stock"
  | "duplicate_customer"
  | "invalid_tax"
  | "incomplete_supplier";

export interface DataQualityIssue {
  type: DataQualityIssueType;
  entityId?: string;
  message: string;
  severity: "info" | "warning" | "critical";
}

export function qualityIssueSummary(
  issues: readonly DataQualityIssue[]
): Readonly<Record<"info" | "warning" | "critical", number>> {
  return issues.reduce(
    (summary, issue) => {
      summary[issue.severity] += 1;
      return summary;
    },
    { info: 0, warning: 0, critical: 0 }
  );
}
