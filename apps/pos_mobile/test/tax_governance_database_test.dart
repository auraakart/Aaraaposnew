import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('finalized sale snapshots applied tax governance evidence', () async {
    final database = LocalPosDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await database.open();
    final context = await database.bootstrapOwner(
      businessName: 'Aaraa Demo Shop',
      storeName: 'Main Store',
    );
    final product = await database.addProduct(
      name: 'Milk',
      unitPriceMinor: 10500,
      taxRateBps: 500,
      taxPriceMode: TaxPriceMode.inclusive,
      taxClassificationType: TaxClassificationType.hsn,
      taxClassificationCode: '0401',
      taxRuleVersionId: 'tax-rule-v1',
    );

    final sale = await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 10500,
    );

    final snapshots = await database.saleTaxSnapshots(sale.saleId);
    expect(snapshots, hasLength(1));
    final snapshot = snapshots.single;
    expect(snapshot.rateBps, 500);
    expect(snapshot.priceMode, TaxPriceMode.inclusive);
    expect(snapshot.classificationType, TaxClassificationType.hsn);
    expect(snapshot.classificationCode, '0401');
    expect(snapshot.taxRuleVersionId, 'tax-rule-v1');
    expect(snapshot.fullyTraceable, isTrue);
  });

  test('hold and resume preserves tax rule evidence', () async {
    final database = LocalPosDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await database.open();
    final context = await database.bootstrapOwner(
      businessName: 'Aaraa Demo Shop',
      storeName: 'Main Store',
    );
    final product = await database.addProduct(
      name: 'Service',
      unitPriceMinor: 11800,
      taxRateBps: 1800,
      taxPriceMode: TaxPriceMode.inclusive,
      taxClassificationType: TaxClassificationType.sac,
      taxClassificationCode: '9983',
      taxRuleVersionId: 'service-rule-v3',
    );

    final heldId = await database.holdSale(
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
    );
    final held = await database.resumeHeldSale(heldId);

    expect(held.lines.single.product.taxClassificationType,
        TaxClassificationType.sac);
    expect(held.lines.single.product.taxClassificationCode, '9983');
    expect(held.lines.single.product.taxRuleVersionId, 'service-rule-v3');

    final sale = await database.finalizeCashSale(
      context: context,
      lines: held.lines,
      tenderedMinor: 11800,
    );
    final snapshot = (await database.saleTaxSnapshots(sale.saleId)).single;
    expect(snapshot.taxRuleVersionId, 'service-rule-v3');
    expect(snapshot.fullyTraceable, isTrue);
  });

  test('classification type and code must be supplied together', () async {
    final database = LocalPosDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await database.open();
    await database.bootstrapOwner(
      businessName: 'Aaraa Demo Shop',
      storeName: 'Main Store',
    );

    await expectLater(
      database.addProduct(
        name: 'Invalid',
        unitPriceMinor: 1000,
        taxClassificationType: TaxClassificationType.hsn,
      ),
      throwsArgumentError,
    );
  });
}
