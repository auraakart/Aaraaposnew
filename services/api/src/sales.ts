export type TaxMode = "intra_state" | "inter_state";
export type TaxPriceMode = "inclusive" | "exclusive";

export interface SaleLineInput {
  productId: string;
  name: string;
  unitPriceMinor: number;
  quantityMilli: number;
  discountMinor: number;
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
    totalMinor
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
