export interface LoyaltyProgram {
  enabled: boolean;
  pointsPer100Rupees: number;
  redemptionMinorPerPoint: number;
  maxRedemptionBps: number;
}

export type LoyaltyEntryType = "earn" | "redeem" | "adjustment_in" | "adjustment_out";

export interface LoyaltyEntry {
  type: LoyaltyEntryType;
  points: number;
}

export interface PromotionLine {
  productId: string;
  grossMinor: number;
  existingDiscountMinor: number;
}

export type PromotionType = "percentage" | "fixed";

export interface Promotion {
  id: string;
  name: string;
  type: PromotionType;
  value: number;
  minBasketMinor: number;
  maxDiscountMinor?: number;
  productIds: readonly string[];
  startsAt: string;
  endsAt: string;
  active: boolean;
}

export interface PromotionEvaluation {
  promotionId: string;
  name: string;
  discountMinor: number;
  lineDiscounts: Readonly<Record<string, number>>;
}

function assertSafeNonNegative(value: number, field: string): void {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error(`${field} must be a non-negative safe integer`);
  }
}

export function validateLoyaltyProgram(program: LoyaltyProgram): void {
  assertSafeNonNegative(program.pointsPer100Rupees, "pointsPer100Rupees");
  assertSafeNonNegative(program.redemptionMinorPerPoint, "redemptionMinorPerPoint");
  assertSafeNonNegative(program.maxRedemptionBps, "maxRedemptionBps");
  if (program.maxRedemptionBps > 10000) {
    throw new Error("maxRedemptionBps cannot exceed 10000");
  }
  if (
    program.enabled &&
    (program.pointsPer100Rupees === 0 || program.redemptionMinorPerPoint === 0)
  ) {
    throw new Error("Enabled loyalty program requires earning and redemption values");
  }
}

export function earnedLoyaltyPoints(
  settledSaleMinor: number,
  program: LoyaltyProgram
): number {
  validateLoyaltyProgram(program);
  assertSafeNonNegative(settledSaleMinor, "settledSaleMinor");
  if (!program.enabled) return 0;
  return Math.floor(
    (settledSaleMinor * program.pointsPer100Rupees) / 10000
  );
}

export function loyaltyBalance(entries: readonly LoyaltyEntry[]): number {
  let balance = 0;
  for (const entry of entries) {
    assertSafeNonNegative(entry.points, "points");
    const increase =
      entry.type === "earn" || entry.type === "adjustment_in";
    balance += increase ? entry.points : -entry.points;
    if (balance < 0) {
      throw new Error("Loyalty points cannot be over-redeemed");
    }
  }
  return balance;
}

export function maxLoyaltyRedemption(input: {
  saleMinor: number;
  availablePoints: number;
  requestedPoints: number;
  program: LoyaltyProgram;
}): { points: number; amountMinor: number } {
  validateLoyaltyProgram(input.program);
  assertSafeNonNegative(input.saleMinor, "saleMinor");
  assertSafeNonNegative(input.availablePoints, "availablePoints");
  assertSafeNonNegative(input.requestedPoints, "requestedPoints");

  if (!input.program.enabled || input.requestedPoints === 0) {
    return { points: 0, amountMinor: 0 };
  }

  const requested = Math.min(input.requestedPoints, input.availablePoints);
  const valueCap = requested * input.program.redemptionMinorPerPoint;
  const saleCap = Math.floor(
    (input.saleMinor * input.program.maxRedemptionBps) / 10000
  );
  const amountMinor = Math.min(valueCap, saleCap, input.saleMinor);
  const points = Math.floor(
    amountMinor / input.program.redemptionMinorPerPoint
  );

  return {
    points,
    amountMinor: points * input.program.redemptionMinorPerPoint
  };
}

function promotionEligible(
  promotion: Promotion,
  lines: readonly PromotionLine[],
  nowIso: string
): boolean {
  if (!promotion.active || nowIso < promotion.startsAt || nowIso >= promotion.endsAt) {
    return false;
  }
  const basketMinor = lines.reduce(
    (sum, line) => sum + line.grossMinor - line.existingDiscountMinor,
    0
  );
  return basketMinor >= promotion.minBasketMinor;
}

export function evaluatePromotion(
  promotion: Promotion,
  lines: readonly PromotionLine[],
  nowIso: string
): PromotionEvaluation | null {
  if (!promotionEligible(promotion, lines, nowIso)) return null;
  if (promotion.type === "percentage" && (promotion.value <= 0 || promotion.value > 10000)) {
    throw new Error("Percentage promotion value must be 1..10000 bps");
  }
  if (promotion.type === "fixed" && promotion.value <= 0) {
    throw new Error("Fixed promotion value must be positive");
  }

  const eligible = lines.filter(
    (line) =>
      promotion.productIds.length === 0 ||
      promotion.productIds.includes(line.productId)
  );
  if (eligible.length === 0) return null;

  const available = eligible.map((line) => {
    assertSafeNonNegative(line.grossMinor, "grossMinor");
    assertSafeNonNegative(line.existingDiscountMinor, "existingDiscountMinor");
    if (line.existingDiscountMinor > line.grossMinor) {
      throw new Error("Existing discount cannot exceed line gross");
    }
    return {
      ...line,
      availableMinor: line.grossMinor - line.existingDiscountMinor
    };
  });
  const eligibleMinor = available.reduce(
    (sum, line) => sum + line.availableMinor,
    0
  );
  if (eligibleMinor <= 0) return null;

  let discountMinor =
    promotion.type === "percentage"
      ? Math.floor((eligibleMinor * promotion.value) / 10000)
      : Math.min(promotion.value, eligibleMinor);

  if (promotion.maxDiscountMinor !== undefined) {
    assertSafeNonNegative(promotion.maxDiscountMinor, "maxDiscountMinor");
    discountMinor = Math.min(discountMinor, promotion.maxDiscountMinor);
  }
  if (discountMinor <= 0) return null;

  const allocations: Record<string, number> = {};
  let allocated = 0;
  for (let index = 0; index < available.length; index += 1) {
    const line = available[index]!;
    const lineDiscount =
      index === available.length - 1
        ? discountMinor - allocated
        : Math.min(
            line.availableMinor,
            Math.floor((discountMinor * line.availableMinor) / eligibleMinor)
          );
    allocations[line.productId] = lineDiscount;
    allocated += lineDiscount;
  }

  return {
    promotionId: promotion.id,
    name: promotion.name,
    discountMinor,
    lineDiscounts: allocations
  };
}

export function selectBestPromotion(
  promotions: readonly Promotion[],
  lines: readonly PromotionLine[],
  nowIso: string
): PromotionEvaluation | null {
  const candidates = promotions
    .map((promotion) => evaluatePromotion(promotion, lines, nowIso))
    .filter((value): value is PromotionEvaluation => value !== null)
    .sort(
      (a, b) =>
        b.discountMinor - a.discountMinor ||
        a.promotionId.localeCompare(b.promotionId)
    );
  return candidates[0] ?? null;
}
