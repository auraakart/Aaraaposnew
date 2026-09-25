import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exclusive intra-state GST splits and totals correctly', () {
    const product = Product(
      id: 'p1',
      name: 'Milk',
      unitPriceMinor: 10000,
      taxRateBps: 500,
      taxPriceMode: TaxPriceMode.exclusive,
    );

    final line = priceSaleLine(
      const SaleLineInput(product: product, quantityMilli: 1000),
      TaxMode.intraState,
    );

    expect(line.taxableMinor, 10000);
    expect(line.taxMinor, 500);
    expect(line.cgstMinor + line.sgstMinor, 500);
    expect(line.igstMinor, 0);
    expect(line.totalMinor, 10500);
  });

  test('inclusive GST preserves displayed price', () {
    const product = Product(
      id: 'p2',
      name: 'Inclusive item',
      unitPriceMinor: 10500,
      taxRateBps: 500,
      taxPriceMode: TaxPriceMode.inclusive,
    );

    final line = priceSaleLine(
      const SaleLineInput(product: product, quantityMilli: 1000),
      TaxMode.intraState,
    );

    expect(line.taxableMinor, 10000);
    expect(line.taxMinor, 500);
    expect(line.totalMinor, 10500);
  });

  test('weighted quantity avoids floating-point money calculations', () {
    const product = Product(
      id: 'p3',
      name: 'Rice',
      unitPriceMinor: 8000,
      taxRateBps: 0,
      taxPriceMode: TaxPriceMode.exclusive,
    );

    final line = priceSaleLine(
      const SaleLineInput(product: product, quantityMilli: 1500),
      TaxMode.intraState,
    );

    expect(line.grossMinor, 12000);
  });

  test('cash change is deterministic', () {
    expect(cashChangeDue(42700, 50000), 7300);
  });

  test('currency formatting does not use floating point', () {
    expect(formatInr(42700), '₹427.00');
    expect(formatInr(73), '₹0.73');
  });
}
