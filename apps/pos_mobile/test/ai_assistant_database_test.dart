import 'package:aaraapos_pos/ai/ai_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('assistant answers sales from recorded local facts', () async {
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

    await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 2000)],
      tenderedMinor: 20000,
    );

    final answer = await database.assistantAnswer(
      'How much did I sell today?',
    );

    expect(answer.classification, InsightClassification.fact);
    expect(answer.answer, contains('₹200.00'));
    expect(
      answer.evidence.any(
        (item) => item.metric == 'today_sales_minor' && item.value == 20000,
      ),
      isTrue,
    );
  });

  test('purchase suggestion is recommendation with inspectable evidence', () async {
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
      lines: [SaleLineInput(product: product, quantityMilli: 9000)],
      tenderedMinor: 90000,
    );

    final insights = await database.generateBusinessInsights();
    final purchase = insights.singleWhere(
      (item) => item.type == 'purchase_suggestion',
    );

    expect(
      purchase.classification,
      InsightClassification.recommendation,
    );
    expect(purchase.message, contains('Consider ordering'));
    expect(
      purchase.evidence.any((item) => item.metric == 'sold_milli'),
      isTrue,
    );
    expect(
      purchase.evidence.any((item) => item.metric == 'on_hand_milli'),
      isTrue,
    );
  });

  test('zero low-stock result still carries evidence', () async {
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

    final answer = await database.assistantAnswer('Show low stock');
    expect(answer.evidence, isNotEmpty);
    expect(answer.evidence.single.value, 0);
  });
}
