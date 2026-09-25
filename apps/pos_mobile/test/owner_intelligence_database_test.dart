import 'package:aaraapos_pos/intelligence/owner_intelligence.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('owner metrics use recorded cost and never fabricate profit', () async {
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
      unitPriceMinor: 10000,
    );
    final supplier = await database.addSupplier(
      name: 'Milk Distributor',
      mobile: '+919999999999',
    );

    final order = await database.createPurchaseOrder(
      context: context,
      supplierId: supplier.id,
      productId: product.id,
      quantityMilli: 10000,
      unitCostMinor: 6000,
    );
    await database.receivePurchaseOrder(
      context: context,
      purchaseOrderId: order,
    );

    await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 2000)],
      tenderedMinor: 20000,
    );
    await database.addExpense(
      context: context,
      category: 'Electricity',
      amountMinor: 2000,
      paymentMethod: 'upi',
    );

    final metrics = await database.businessMetrics(
      ReportPeriod.today,
      now: DateTime.now(),
    );

    expect(metrics.salesMinor, 20000);
    expect(metrics.billCount, 1);
    expect(metrics.moneyReceivedMinor, 20000);
    expect(metrics.expensesMinor, 2000);
    expect(metrics.costCoverageBps, 10000);
    expect(metrics.estimatedProfitMinor, 6000);

    final timeline = await database.businessTimeline();
    expect(timeline.any((item) => item.type == 'sale'), isTrue);
    expect(timeline.any((item) => item.type == 'purchase_receipt'), isTrue);
    expect(timeline.any((item) => item.type == 'expense'), isTrue);
  });

  test('quality checks surface duplicate products and missing price', () async {
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

    await database.addProduct(name: 'Milk', unitPriceMinor: 10000);
    await database.addProduct(name: ' milk ', unitPriceMinor: 0);

    final issues = await database.dataQualityIssues();
    expect(
      issues.any((issue) => issue.type == 'duplicate_product'),
      isTrue,
    );
    expect(
      issues.any((issue) => issue.type == 'missing_price'),
      isTrue,
    );
  });
}
