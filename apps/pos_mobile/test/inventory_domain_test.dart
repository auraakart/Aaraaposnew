import 'package:aaraapos_pos/inventory/inventory_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sale decreases stock and damage requires a reason', () {
    expect(
      () => validateStockMovement(
        type: StockMovementType.sale,
        quantityDeltaMilli: -1000,
      ),
      returnsNormally,
    );
    expect(
      () => validateStockMovement(
        type: StockMovementType.damage,
        quantityDeltaMilli: -1000,
      ),
      throwsArgumentError,
    );
  });

  test('stock count creates only the variance', () {
    expect(
      countAdjustmentDelta(currentOnHandMilli: 12000, countedMilli: 10500),
      -1500,
    );
  });

  test('health exposes negative and low stock distinctly', () {
    expect(
      stockHealth(onHandMilli: -1000, reorderLevelMilli: 5000),
      StockHealth.negative,
    );
    expect(
      stockHealth(onHandMilli: 4000, reorderLevelMilli: 5000),
      StockHealth.low,
    );
  });
}
