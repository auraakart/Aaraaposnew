enum TaxMode { intraState, interState }

enum TaxPriceMode { inclusive, exclusive }

enum TaxClassificationType { hsn, sac, other }

String taxClassificationTypeValue(TaxClassificationType value) => switch (value) {
      TaxClassificationType.hsn => 'hsn',
      TaxClassificationType.sac => 'sac',
      TaxClassificationType.other => 'other',
    };

TaxClassificationType? taxClassificationTypeFromValue(String? value) =>
    switch (value) {
      'hsn' => TaxClassificationType.hsn,
      'sac' => TaxClassificationType.sac,
      'other' => TaxClassificationType.other,
      _ => null,
    };

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.unitPriceMinor,
    required this.taxRateBps,
    required this.taxPriceMode,
    this.barcode,
    this.taxClassificationType,
    this.taxClassificationCode,
    this.taxRuleVersionId,
  });

  final String id;
  final String name;
  final String? barcode;
  final int unitPriceMinor;
  final int taxRateBps;
  final TaxPriceMode taxPriceMode;
  final TaxClassificationType? taxClassificationType;
  final String? taxClassificationCode;
  final String? taxRuleVersionId;
}

class SaleLineInput {
  const SaleLineInput({
    required this.product,
    required this.quantityMilli,
    this.discountMinor = 0,
    this.discountSource,
    this.discountReferenceId,
  });

  final Product product;
  final int quantityMilli;
  final int discountMinor;
  final String? discountSource;
  final String? discountReferenceId;
}

class PricedSaleLine {
  const PricedSaleLine({
    required this.product,
    required this.quantityMilli,
    required this.grossMinor,
    required this.discountMinor,
    required this.taxableMinor,
    required this.cgstMinor,
    required this.sgstMinor,
    required this.igstMinor,
    required this.taxMinor,
    required this.totalMinor,
    this.discountSource,
    this.discountReferenceId,
  });

  final Product product;
  final int quantityMilli;
  final int grossMinor;
  final int discountMinor;
  final int taxableMinor;
  final int cgstMinor;
  final int sgstMinor;
  final int igstMinor;
  final int taxMinor;
  final int totalMinor;
  final String? discountSource;
  final String? discountReferenceId;
}

class SaleTaxSnapshot {
  const SaleTaxSnapshot({
    required this.saleLineId,
    required this.productId,
    required this.rateBps,
    required this.priceMode,
    this.classificationType,
    this.classificationCode,
    this.taxRuleVersionId,
  });

  final String saleLineId;
  final String productId;
  final int? rateBps;
  final TaxPriceMode? priceMode;
  final TaxClassificationType? classificationType;
  final String? classificationCode;
  final String? taxRuleVersionId;

  bool get fullyTraceable =>
      rateBps != null &&
      priceMode != null &&
      classificationType != null &&
      classificationCode != null &&
      taxRuleVersionId != null;
}

class SaleTotals {
  const SaleTotals({
    required this.lines,
    required this.subtotalMinor,
    required this.discountMinor,
    required this.taxMinor,
    required this.totalMinor,
  });

  final List<PricedSaleLine> lines;
  final int subtotalMinor;
  final int discountMinor;
  final int taxMinor;
  final int totalMinor;
}

int _roundDiv(int numerator, int denominator) {
  if (numerator < 0 || denominator <= 0) {
    throw ArgumentError('Invalid rounding operands');
  }
  return (numerator + (denominator ~/ 2)) ~/ denominator;
}

PricedSaleLine priceSaleLine(SaleLineInput input, TaxMode taxMode) {
  final product = input.product;
  if (product.unitPriceMinor < 0 ||
      product.taxRateBps < 0 ||
      product.taxRateBps > 10000 ||
      input.quantityMilli <= 0 ||
      input.discountMinor < 0) {
    throw ArgumentError('Invalid sale line');
  }

  final grossMinor =
      _roundDiv(product.unitPriceMinor * input.quantityMilli, 1000);
  if (input.discountMinor > grossMinor) {
    throw ArgumentError('Discount cannot exceed line gross');
  }

  final afterDiscountMinor = grossMinor - input.discountMinor;
  late final int taxableMinor;
  late final int taxMinor;
  late final int totalMinor;

  if (product.taxPriceMode == TaxPriceMode.inclusive) {
    taxMinor = product.taxRateBps == 0
        ? 0
        : _roundDiv(
            afterDiscountMinor * product.taxRateBps,
            10000 + product.taxRateBps,
          );
    taxableMinor = afterDiscountMinor - taxMinor;
    totalMinor = afterDiscountMinor;
  } else {
    taxableMinor = afterDiscountMinor;
    taxMinor = _roundDiv(taxableMinor * product.taxRateBps, 10000);
    totalMinor = taxableMinor + taxMinor;
  }

  final int cgstMinor;
  final int sgstMinor;
  final int igstMinor;
  if (taxMode == TaxMode.interState) {
    cgstMinor = 0;
    sgstMinor = 0;
    igstMinor = taxMinor;
  } else {
    cgstMinor = taxMinor ~/ 2;
    sgstMinor = taxMinor - cgstMinor;
    igstMinor = 0;
  }

  return PricedSaleLine(
    product: product,
    quantityMilli: input.quantityMilli,
    grossMinor: grossMinor,
    discountMinor: input.discountMinor,
    taxableMinor: taxableMinor,
    cgstMinor: cgstMinor,
    sgstMinor: sgstMinor,
    igstMinor: igstMinor,
    taxMinor: taxMinor,
    totalMinor: totalMinor,
    discountSource: input.discountSource,
    discountReferenceId: input.discountReferenceId,
  );
}

SaleTotals priceSale(List<SaleLineInput> inputs, TaxMode taxMode) {
  if (inputs.isEmpty) {
    throw ArgumentError('Sale requires at least one line');
  }

  final lines = inputs.map((line) => priceSaleLine(line, taxMode)).toList();
  return SaleTotals(
    lines: lines,
    subtotalMinor: lines.fold(0, (sum, line) => sum + line.grossMinor),
    discountMinor: lines.fold(0, (sum, line) => sum + line.discountMinor),
    taxMinor: lines.fold(0, (sum, line) => sum + line.taxMinor),
    totalMinor: lines.fold(0, (sum, line) => sum + line.totalMinor),
  );
}

int cashChangeDue(int totalMinor, int tenderedMinor) {
  if (totalMinor < 0 || tenderedMinor < totalMinor) {
    throw ArgumentError('Cash tender is insufficient');
  }
  return tenderedMinor - totalMinor;
}

String formatInr(int minor) {
  final sign = minor < 0 ? '-' : '';
  final absolute = minor.abs();
  final rupees = absolute ~/ 100;
  final paise = (absolute % 100).toString().padLeft(2, '0');
  return '$sign₹$rupees.$paise';
}
