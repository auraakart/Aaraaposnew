export type StockMovementType =
  | "opening"
  | "receive"
  | "sale"
  | "return_in"
  | "adjustment"
  | "damage"
  | "loss"
  | "transfer_in"
  | "transfer_out"
  | "purchase_return";

export interface StockMovement {
  id: string;
  productId: string;
  quantityDeltaMilli: number;
  type: StockMovementType;
  reason?: string;
  sourceEntityType?: string;
  sourceEntityId?: string;
}

export type StockHealth = "healthy" | "low" | "out" | "negative";

function assertQuantityDelta(value: number): void {
  if (!Number.isSafeInteger(value) || value === 0) {
    throw new Error("Stock movement must be a non-zero integer milli-unit delta");
  }
}

export function validateStockMovement(movement: StockMovement): void {
  assertQuantityDelta(movement.quantityDeltaMilli);

  const shouldBePositive = new Set<StockMovementType>([
    "opening",
    "receive",
    "return_in",
    "transfer_in"
  ]);
  const shouldBeNegative = new Set<StockMovementType>([
    "sale",
    "damage",
    "loss",
    "transfer_out",
    "purchase_return"
  ]);

  if (shouldBePositive.has(movement.type) && movement.quantityDeltaMilli <= 0) {
    throw new Error(`${movement.type} movement must increase stock`);
  }
  if (shouldBeNegative.has(movement.type) && movement.quantityDeltaMilli >= 0) {
    throw new Error(`${movement.type} movement must reduce stock`);
  }
  if (
    ["adjustment", "damage", "loss"].includes(movement.type) &&
    !movement.reason?.trim()
  ) {
    throw new Error(`${movement.type} movement requires a reason`);
  }
}

export function deriveOnHandMilli(
  movements: readonly StockMovement[]
): number {
  let onHand = 0;
  for (const movement of movements) {
    validateStockMovement(movement);
    onHand += movement.quantityDeltaMilli;
  }
  return onHand;
}

export function countAdjustmentDelta(
  currentOnHandMilli: number,
  countedMilli: number
): number {
  if (
    !Number.isSafeInteger(currentOnHandMilli) ||
    !Number.isSafeInteger(countedMilli) ||
    countedMilli < 0
  ) {
    throw new Error("Invalid stock count");
  }
  return countedMilli - currentOnHandMilli;
}

export function stockHealth(
  onHandMilli: number,
  reorderLevelMilli: number
): StockHealth {
  if (
    !Number.isSafeInteger(onHandMilli) ||
    !Number.isSafeInteger(reorderLevelMilli) ||
    reorderLevelMilli < 0
  ) {
    throw new Error("Invalid stock health input");
  }
  if (onHandMilli < 0) return "negative";
  if (onHandMilli === 0) return "out";
  if (onHandMilli <= reorderLevelMilli) return "low";
  return "healthy";
}
