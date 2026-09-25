export type TaxMode = "intra_state" | "inter_state";
export type TaxPriceMode = "inclusive" | "exclusive";

export interface SaleLineInput {
  productId: string;
  name: string;
  unitPriceMinor: number;
  quantityMilli: number;
  discountMinor: number;
  discountSource?: "manual" | "promotion" | "loyalty";
  discountReferenceId?: string;
  taxRateBps: number;
  taxPriceMode: TaxPriceMode;
}

export interface PricedSaleLine {
  productId: string;
  name: string;
  quantityMilli: number;
  grossMinor: number;
  discountMinor: number;
  taxableMinor: number;
  cgstMinor: number;
  sgstMinor: number;
  igstMinor: number;
  taxMinor: number;
  totalMinor: number;
  discountSource?: "manual" | "promotion" | "loyalty";
  discountReferenceId?: string;
}

export interface SaleTotals {
  subtotalMinor: number;
  discountMinor: number;
  taxMinor: number;
  totalMinor: number;
  lines: readonly PricedSaleLine[];
}

function assertInteger(name: string, value: number): void {
  if (!Number.isSafeInteger(value)) {
    throw new Error(`${name} must be a safe integer`);
  }
}

function roundDiv(numerator: number, denominator: number): number {
  assertInteger("numerator", numerator);
  assertInteger("denominator", denominator);
  if (denominator <= 0 || numerator < 0) {
    throw new Error("roundDiv expects a non-negative numerator and positive denominator");
  }
  return Math.floor((numerator + Math.floor(denominator / 2)) / denominator);
}

function splitTax(totalTaxMinor: number, mode: TaxMode): Pick<PricedSaleLine, "cgstMinor" | "sgstMinor" | "igstMinor"> {
  if (mode === "inter_state") {
    return { cgstMinor: 0, sgstMinor: 0, igstMinor: totalTaxMinor };
  }

  const cgstMinor = Math.floor(totalTaxMinor / 2);
  return {
    cgstMinor,
    sgstMinor: totalTaxMinor - cgstMinor,
    igstMinor: 0
  };
}

export function priceSaleLine(line: SaleLineInput, taxMode: TaxMode): PricedSaleLine {
  for (const [name, value] of Object.entries({
    unitPriceMinor: line.unitPriceMinor,
    quantityMilli: line.quantityMilli,
    discountMinor: line.discountMinor,
    taxRateBps: line.taxRateBps
  })) {
    assertInteger(name, value);
    if (value < 0) {
      throw new Error(`${name} cannot be negative`);
    }
  }

  if (line.quantityMilli <= 0) {
    throw new Error("quantityMilli must be greater than zero");
  }
  if (line.taxRateBps > 10000) {
    throw new Error("taxRateBps cannot exceed 10000");
  }

  const grossMinor = roundDiv(line.unitPriceMinor * line.quantityMilli, 1000);
  if (line.discountMinor > grossMinor) {
    throw new Error("discount cannot exceed line gross");
  }

  const afterDiscountMinor = grossMinor - line.discountMinor;
  let taxableMinor: number;
  let taxMinor: number;
  let totalMinor: number;

  if (line.taxPriceMode === "inclusive") {
    taxMinor = line.taxRateBps === 0
      ? 0
      : roundDiv(afterDiscountMinor * line.taxRateBps, 10000 + line.taxRateBps);
    taxableMinor = afterDiscountMinor - taxMinor;
    totalMinor = afterDiscountMinor;
  } else {
    taxableMinor = afterDiscountMinor;
    taxMinor = roundDiv(taxableMinor * line.taxRateBps, 10000);
    totalMinor = taxableMinor + taxMinor;
  }

  return {
    productId: line.productId,
    name: line.name,
    quantityMilli: line.quantityMilli,
    grossMinor,
    discountMinor: line.discountMinor,
    taxableMinor,
    ...splitTax(taxMinor, taxMode),
    taxMinor,
    totalMinor,
    ...(line.discountSource === undefined
      ? {}
      : { discountSource: line.discountSource }),
    ...(line.discountReferenceId === undefined
      ? {}
      : { discountReferenceId: line.discountReferenceId })
  };
}

export function priceSale(lines: readonly SaleLineInput[], taxMode: TaxMode): SaleTotals {
  if (lines.length === 0) {
    throw new Error("sale requires at least one line");
  }

  const priced = lines.map((line) => priceSaleLine(line, taxMode));
  return {
    subtotalMinor: priced.reduce((sum, line) => sum + line.grossMinor, 0),
    discountMinor: priced.reduce((sum, line) => sum + line.discountMinor, 0),
    taxMinor: priced.reduce((sum, line) => sum + line.taxMinor, 0),
    totalMinor: priced.reduce((sum, line) => sum + line.totalMinor, 0),
    lines: priced
  };
}

export function cashChangeDue(totalMinor: number, tenderedMinor: number): number {
  assertInteger("totalMinor", totalMinor);
  assertInteger("tenderedMinor", tenderedMinor);
  if (totalMinor < 0 || tenderedMinor < totalMinor) {
    throw new Error("cash tender is insufficient");
  }
  return tenderedMinor - totalMinor;
}


export type ReturnRefundMethod = "cash" | "customer_credit" | "upi" | "card";

export interface ReturnLineSource {
  saleLineId: string;
  productId: string;
  soldQuantityMilli: number;
  alreadyReturnedQuantityMilli: number;
  requestedReturnQuantityMilli: number;
  taxableMinor: number;
  cgstMinor: number;
  sgstMinor: number;
  igstMinor: number;
  taxMinor: number;
  totalMinor: number;
}

export interface PricedReturnLine {
  saleLineId: string;
  productId: string;
  quantityMilli: number;
  taxableMinor: number;
  cgstMinor: number;
  sgstMinor: number;
  igstMinor: number;
  taxMinor: number;
  totalMinor: number;
}

function prorateMinor(
  originalMinor: number,
  partQuantityMilli: number,
  originalQuantityMilli: number
): number {
  assertInteger("originalMinor", originalMinor);
  assertInteger("partQuantityMilli", partQuantityMilli);
  assertInteger("originalQuantityMilli", originalQuantityMilli);
  if (originalMinor < 0 || partQuantityMilli < 0 || originalQuantityMilli <= 0) {
    throw new Error("invalid return proration inputs");
  }
  return roundDiv(originalMinor * partQuantityMilli, originalQuantityMilli);
}

export function priceReturnLine(source: ReturnLineSource): PricedReturnLine {
  const remainingMilli =
    source.soldQuantityMilli - source.alreadyReturnedQuantityMilli;
  if (
    source.soldQuantityMilli <= 0 ||
    source.alreadyReturnedQuantityMilli < 0 ||
    source.requestedReturnQuantityMilli <= 0 ||
    remainingMilli < source.requestedReturnQuantityMilli
  ) {
    throw new Error("return quantity exceeds refundable quantity");
  }

  const quantityMilli = source.requestedReturnQuantityMilli;
  return {
    saleLineId: source.saleLineId,
    productId: source.productId,
    quantityMilli,
    taxableMinor: prorateMinor(
      source.taxableMinor,
      quantityMilli,
      source.soldQuantityMilli
    ),
    cgstMinor: prorateMinor(
      source.cgstMinor,
      quantityMilli,
      source.soldQuantityMilli
    ),
    sgstMinor: prorateMinor(
      source.sgstMinor,
      quantityMilli,
      source.soldQuantityMilli
    ),
    igstMinor: prorateMinor(
      source.igstMinor,
      quantityMilli,
      source.soldQuantityMilli
    ),
    taxMinor: prorateMinor(
      source.taxMinor,
      quantityMilli,
      source.soldQuantityMilli
    ),
    totalMinor: prorateMinor(
      source.totalMinor,
      quantityMilli,
      source.soldQuantityMilli
    )
  };
}

export function requiresDiscountApproval(input: {
  lineGrossMinor: number;
  discountMinor: number;
  actorRole: "owner" | "manager" | "cashier" | "stock_worker";
  cashierSelfApprovalLimitBps?: number;
}): boolean {
  assertInteger("lineGrossMinor", input.lineGrossMinor);
  assertInteger("discountMinor", input.discountMinor);
  if (input.lineGrossMinor <= 0 || input.discountMinor < 0) {
    throw new Error("invalid discount approval inputs");
  }
  if (input.discountMinor > input.lineGrossMinor) {
    throw new Error("discount cannot exceed line gross");
  }
  if (input.discountMinor === 0) return false;
  if (input.actorRole === "owner" || input.actorRole === "manager") return false;
  if (input.actorRole === "stock_worker") return true;

  const limitBps = input.cashierSelfApprovalLimitBps ?? 500;
  assertInteger("cashierSelfApprovalLimitBps", limitBps);
  const discountBps = Math.floor(
    (input.discountMinor * 10000) / input.lineGrossMinor
  );
  return discountBps > limitBps;
}
