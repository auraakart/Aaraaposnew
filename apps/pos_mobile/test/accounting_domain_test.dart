import 'package:aaraapos_pos/accounting/accounting_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sale = AccountingExportRow(
    kind: AccountingRegisterKind.sales,
    sourceId: 'sale-1',
    documentNumber: 'INV-1',
    occurredAt: _fixedDate,
    partyName: '=Ramesh',
    description: '+Retail sale',
    balanceEffect: 'increase',
    grossMinor: 11800,
    discountMinor: 0,
    tax: AccountingTaxBreakdown(
      taxableMinor: 10000,
      cgstMinor: 900,
      sgstMinor: 900,
      igstMinor: 0,
      unclassifiedTaxMinor: 0,
    ),
    totalMinor: 11800,
    paymentMethod: 'cash',
    status: 'finalized',
  );

  test('manifest keeps output GST separate from purchase tax', () {
    final manifest = buildAccountingManifest([
      sale,
      AccountingExportRow(
        kind: AccountingRegisterKind.returns,
        sourceId: 'return-1',
        occurredAt: _fixedDate,
        description: 'Full return',
        balanceEffect: 'decrease',
        grossMinor: 11800,
        discountMinor: 0,
        tax: AccountingTaxBreakdown(
          taxableMinor: 10000,
          cgstMinor: 900,
          sgstMinor: 900,
          igstMinor: 0,
          unclassifiedTaxMinor: 0,
        ),
        totalMinor: 11800,
      ),
      AccountingExportRow(
        kind: AccountingRegisterKind.purchases,
        sourceId: 'purchase-1',
        occurredAt: _fixedDate,
        description: 'Purchase receipt',
        balanceEffect: 'increase',
        grossMinor: 7080,
        discountMinor: 0,
        tax: AccountingTaxBreakdown(
          taxableMinor: 6000,
          cgstMinor: 0,
          sgstMinor: 0,
          igstMinor: 0,
          unclassifiedTaxMinor: 1080,
        ),
        totalMinor: 7080,
      ),
    ]);

    expect(manifest.salesCgstMinor, 900);
    expect(manifest.returnsCgstMinor, 900);
    expect(manifest.outputCgstAfterReturnsMinor, 0);
    expect(manifest.purchaseTaxableMinor, 6000);
    expect(manifest.purchaseUnclassifiedTaxMinor, 1080);
  });

  test('CSV neutralizes spreadsheet formulas and uses decimal rupees', () {
    final csv = accountingRowsToCsv([sale]);

    expect(csv, contains("'=Ramesh"));
    expect(csv, contains("'+Retail sale"));
    expect(csv, contains('"118.00"'));
    expect(csv, contains('"100.00"'));
  });
}

final _fixedDate = DateTime.utc(2026, 9, 25, 10);
