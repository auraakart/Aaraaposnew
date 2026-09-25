import test from "node:test";
import assert from "node:assert/strict";
import {
  earnedLoyaltyPoints,
  loyaltyBalance,
  maxLoyaltyRedemption,
  selectBestPromotion,
  type LoyaltyProgram
} from "../src/loyalty.js";

const program: LoyaltyProgram = {
  enabled: true,
  pointsPer100Rupees: 2,
  redemptionMinorPerPoint: 100,
  maxRedemptionBps: 2000
};

test("loyalty earning uses integer sale value", () => {
  assert.equal(earnedLoyaltyPoints(125000, program), 25);
});

test("loyalty ledger is append-only and cannot over-redeem", () => {
  assert.equal(
    loyaltyBalance([
      { type: "earn", points: 20 },
      { type: "redeem", points: 5 },
      { type: "adjustment_in", points: 2 }
    ]),
    17
  );
  assert.throws(() =>
    loyaltyBalance([
      { type: "earn", points: 5 },
      { type: "redeem", points: 6 }
    ])
  );
});

test("redemption respects point balance and percentage cap", () => {
  assert.deepEqual(
    maxLoyaltyRedemption({
      saleMinor: 10000,
      availablePoints: 100,
      requestedPoints: 100,
      program
    }),
    { points: 20, amountMinor: 2000 }
  );
});

test("best promotion is deterministic and does not stack", () => {
  const lines = [
    { productId: "milk", grossMinor: 10000, existingDiscountMinor: 0 },
    { productId: "bread", grossMinor: 5000, existingDiscountMinor: 0 }
  ];
  const result = selectBestPromotion(
    [
      {
        id: "p10",
        name: "10% off",
        type: "percentage",
        value: 1000,
        minBasketMinor: 0,
        productIds: [],
        startsAt: "2026-09-01T00:00:00Z",
        endsAt: "2026-10-01T00:00:00Z",
        active: true
      },
      {
        id: "fixed",
        name: "₹20 off milk",
        type: "fixed",
        value: 2000,
        minBasketMinor: 0,
        productIds: ["milk"],
        startsAt: "2026-09-01T00:00:00Z",
        endsAt: "2026-10-01T00:00:00Z",
        active: true
      }
    ],
    lines,
    "2026-09-25T10:00:00Z"
  );

  assert.equal(result?.promotionId, "fixed");
  assert.equal(result?.discountMinor, 2000);
  assert.deepEqual(result?.lineDiscounts, { milk: 2000 });
});
