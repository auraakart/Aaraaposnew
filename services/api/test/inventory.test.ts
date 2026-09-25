import test from "node:test";
import assert from "node:assert/strict";
import {
  countAdjustmentDelta,
  deriveOnHandMilli,
  stockHealth,
  validateStockMovement
} from "../src/inventory.js";

test("on-hand stock is derived from append-only movements", () => {
  assert.equal(
    deriveOnHandMilli([
      {
        id: "m1",
        productId: "p1",
        type: "opening",
        quantityDeltaMilli: 10000
      },
      {
        id: "m2",
        productId: "p1",
        type: "sale",
        quantityDeltaMilli: -2000,
        sourceEntityType: "sale",
        sourceEntityId: "s1"
      },
      {
        id: "m3",
        productId: "p1",
        type: "receive",
        quantityDeltaMilli: 5000
      }
    ]),
    13000
  );
});

test("damage loss and manual adjustment require reasons", () => {
  assert.throws(() =>
    validateStockMovement({
      id: "m",
      productId: "p",
      type: "damage",
      quantityDeltaMilli: -1000
    })
  );
});

test("stock count creates only the difference", () => {
  assert.equal(countAdjustmentDelta(12000, 10500), -1500);
  assert.equal(countAdjustmentDelta(12000, 12000), 0);
});

test("stock health distinguishes low out and suspicious negative", () => {
  assert.equal(stockHealth(10000, 5000), "healthy");
  assert.equal(stockHealth(5000, 5000), "low");
  assert.equal(stockHealth(0, 5000), "out");
  assert.equal(stockHealth(-1000, 5000), "negative");
});
