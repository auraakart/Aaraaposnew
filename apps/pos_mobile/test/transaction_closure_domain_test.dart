import 'package:aaraapos_pos/sell/return_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('return proration preserves integer money', () {
    expect(
      prorateReturnMinor(
        originalMinor: 21000,
        partQuantityMilli: 1000,
        originalQuantityMilli: 2000,
      ),
      10500,
    );
  });

  test('cashier high discount requires approval but manager does not', () {
    expect(
      discountRequiresApproval(
        lineGrossMinor: 10000,
        discountMinor: 600,
        actorRole: 'cashier',
      ),
      isTrue,
    );
    expect(
      discountRequiresApproval(
        lineGrossMinor: 10000,
        discountMinor: 600,
        actorRole: 'manager',
      ),
      isFalse,
    );
  });
}
