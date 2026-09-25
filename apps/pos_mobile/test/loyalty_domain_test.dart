import 'package:aaraapos_pos/loyalty/loyalty_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const program = LoyaltyProgram(
    enabled: true,
    pointsPer100Rupees: 2,
    redemptionMinorPerPoint: 100,
    maxRedemptionBps: 2000,
  );

  test('loyalty points earn and redemption caps are deterministic', () {
    expect(earnedLoyaltyPoints(125000, program), 25);
    expect(
      maxLoyaltyRedemption(
        saleMinor: 10000,
        availablePoints: 100,
        requestedPoints: 100,
        program: program,
      ),
      (points: 20, amountMinor: 2000),
    );
  });

  test('best promotion wins without stacking', () {
    final now = DateTime.utc(2026, 9, 25);
    final best = selectBestPromotion(
      promotions: [
        LocalPromotion(
          id: 'ten',
          name: '10% off',
          type: 'percentage',
          value: 1000,
          minBasketMinor: 0,
          startsAt: now.subtract(const Duration(days: 1)),
          endsAt: now.add(const Duration(days: 1)),
          active: true,
          productIds: const [],
        ),
        LocalPromotion(
          id: 'fixed',
          name: '₹20 off',
          type: 'fixed',
          value: 2000,
          minBasketMinor: 0,
          startsAt: now.subtract(const Duration(days: 1)),
          endsAt: now.add(const Duration(days: 1)),
          active: true,
          productIds: const ['milk'],
        ),
      ],
      grossMinorByProduct: const {'milk': 10000, 'bread': 5000},
      existingDiscountMinorByProduct: const {},
      now: now,
    );

    expect(best?.promotion.id, 'fixed');
    expect(best?.discountMinor, 2000);
    expect(best?.lineDiscounts, {'milk': 2000});
  });
}
