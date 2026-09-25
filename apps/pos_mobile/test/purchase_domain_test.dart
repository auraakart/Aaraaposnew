import 'package:aaraapos_pos/purchases/purchase_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('purchase line supports weighted quantity with integer money', () {
    expect(
      purchaseLineTotalMinor(
        quantityMilli: 1500,
        unitCostMinor: 8000,
        taxMinor: 600,
      ),
      12600,
    );
  });

  test('purchase line rejects invalid quantities and costs', () {
    expect(
      () => purchaseLineTotalMinor(
        quantityMilli: 0,
        unitCostMinor: 8000,
      ),
      throwsArgumentError,
    );
  });
}
