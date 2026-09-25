class LoyaltyProgram {
  const LoyaltyProgram({
    required this.enabled,
    required this.pointsPer100Rupees,
    required this.redemptionMinorPerPoint,
    required this.maxRedemptionBps,
  });

  final bool enabled;
  final int pointsPer100Rupees;
  final int redemptionMinorPerPoint;
  final int maxRedemptionBps;
}

class LocalPromotion {
  const LocalPromotion({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    required this.minBasketMinor,
    required this.startsAt,
    required this.endsAt,
    required this.active,
    required this.productIds,
    this.maxDiscountMinor,
  });

  final String id;
  final String name;
  final String type;
  final int value;
  final int minBasketMinor;
  final int? maxDiscountMinor;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool active;
  final List<String> productIds;
}

class PromotionEvaluation {
  const PromotionEvaluation({
    required this.promotion,
    required this.discountMinor,
    required this.lineDiscounts,
  });

  final LocalPromotion promotion;
  final int discountMinor;
  final Map<String, int> lineDiscounts;
}

void validateLoyaltyProgram(LoyaltyProgram program) {
  if (program.pointsPer100Rupees < 0 ||
      program.redemptionMinorPerPoint < 0 ||
      program.maxRedemptionBps < 0 ||
      program.maxRedemptionBps > 10000) {
    throw ArgumentError('Invalid loyalty program');
  }
  if (program.enabled &&
      (program.pointsPer100Rupees == 0 ||
          program.redemptionMinorPerPoint == 0)) {
    throw ArgumentError('Enabled loyalty requires earn and redeem values');
  }
}

int earnedLoyaltyPoints(int settledSaleMinor, LoyaltyProgram program) {
  validateLoyaltyProgram(program);
  if (settledSaleMinor < 0) {
    throw ArgumentError('Sale value cannot be negative');
  }
  if (!program.enabled) return 0;
  return settledSaleMinor * program.pointsPer100Rupees ~/ 10000;
}

({int points, int amountMinor}) maxLoyaltyRedemption({
  required int saleMinor,
  required int availablePoints,
  required int requestedPoints,
  required LoyaltyProgram program,
}) {
  validateLoyaltyProgram(program);
  if (saleMinor < 0 || availablePoints < 0 || requestedPoints < 0) {
    throw ArgumentError('Loyalty redemption values cannot be negative');
  }
  if (!program.enabled || requestedPoints == 0) {
    return (points: 0, amountMinor: 0);
  }
  final requested = requestedPoints < availablePoints
      ? requestedPoints
      : availablePoints;
  final valueCap = requested * program.redemptionMinorPerPoint;
  final saleCap = saleMinor * program.maxRedemptionBps ~/ 10000;
  var amount = valueCap;
  if (amount > saleCap) amount = saleCap;
  if (amount > saleMinor) amount = saleMinor;
  final points = amount ~/ program.redemptionMinorPerPoint;
  return (
    points: points,
    amountMinor: points * program.redemptionMinorPerPoint,
  );
}

PromotionEvaluation? evaluatePromotion({
  required LocalPromotion promotion,
  required Map<String, int> grossMinorByProduct,
  required Map<String, int> existingDiscountMinorByProduct,
  required DateTime now,
}) {
  if (!promotion.active ||
      now.toUtc().isBefore(promotion.startsAt.toUtc()) ||
      !now.toUtc().isBefore(promotion.endsAt.toUtc())) {
    return null;
  }

  final basketMinor = grossMinorByProduct.entries.fold<int>(
    0,
    (sum, entry) =>
        sum +
        entry.value -
        (existingDiscountMinorByProduct[entry.key] ?? 0),
  );
  if (basketMinor < promotion.minBasketMinor) return null;

  final eligibleIds = grossMinorByProduct.keys.where(
    (id) =>
        promotion.productIds.isEmpty || promotion.productIds.contains(id),
  );
  final available = <String, int>{};
  for (final id in eligibleIds) {
    final gross = grossMinorByProduct[id] ?? 0;
    final existing = existingDiscountMinorByProduct[id] ?? 0;
    if (gross < 0 || existing < 0 || existing > gross) {
      throw ArgumentError('Invalid promotion line');
    }
    final remaining = gross - existing;
    if (remaining > 0) available[id] = remaining;
  }
  if (available.isEmpty) return null;

  final eligibleMinor = available.values.fold<int>(0, (a, b) => a + b);
  var discountMinor = promotion.type == 'percentage'
      ? eligibleMinor * promotion.value ~/ 10000
      : promotion.value;
  if (discountMinor > eligibleMinor) discountMinor = eligibleMinor;
  final max = promotion.maxDiscountMinor;
  if (max != null && discountMinor > max) discountMinor = max;
  if (discountMinor <= 0) return null;

  final lineDiscounts = <String, int>{};
  var allocated = 0;
  final entries = available.entries.toList();
  for (var i = 0; i < entries.length; i++) {
    final entry = entries[i];
    final share = i == entries.length - 1
        ? discountMinor - allocated
        : discountMinor * entry.value ~/ eligibleMinor;
    lineDiscounts[entry.key] = share > entry.value ? entry.value : share;
    allocated += lineDiscounts[entry.key]!;
  }

  return PromotionEvaluation(
    promotion: promotion,
    discountMinor: discountMinor,
    lineDiscounts: lineDiscounts,
  );
}

PromotionEvaluation? selectBestPromotion({
  required List<LocalPromotion> promotions,
  required Map<String, int> grossMinorByProduct,
  required Map<String, int> existingDiscountMinorByProduct,
  required DateTime now,
}) {
  final values = promotions
      .map(
        (promotion) => evaluatePromotion(
          promotion: promotion,
          grossMinorByProduct: grossMinorByProduct,
          existingDiscountMinorByProduct: existingDiscountMinorByProduct,
          now: now,
        ),
      )
      .whereType<PromotionEvaluation>()
      .toList()
    ..sort(
      (a, b) =>
          b.discountMinor.compareTo(a.discountMinor) != 0
              ? b.discountMinor.compareTo(a.discountMinor)
              : a.promotion.id.compareTo(b.promotion.id),
    );
  return values.isEmpty ? null : values.first;
}
