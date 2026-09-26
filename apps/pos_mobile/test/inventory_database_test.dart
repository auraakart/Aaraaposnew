import 'package:aaraapos_pos/inventory/inventory_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('receive sale and count produce traceable stock balance', () async {
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
      reorderLevelMilli: 3000,
    );

    await database.recordStockMovement(
      context: context,
      productId: product.id,
      type: StockMovementType.receive,
      quantityDeltaMilli: 10000,
    );

    await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 2000)],
      tenderedMinor: 20000,
    );

    var inventory = await database.listInventory();
    expect(inventory.single.onHandMilli, 8000);
    expect(inventory.single.health, StockHealth.healthy);

    await database.countStock(
      context: context,
      productId: product.id,
      countedMilli: 2500,
      reason: 'Physical count',
    );

    inventory = await database.listInventory();
    expect(inventory.single.onHandMilli, 2500);
    expect(inventory.single.health, StockHealth.low);
    final outbox = await database.listOutboxItems();
    expect(
      outbox.where((item) => item.entityType != 'audit_event').length,
      3,
    );
    expect(
      outbox.where((item) => item.entityType == 'audit_event').length,
      3,
    );
  });

  test('damage and loss require reasons', () async {
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
      name: 'Bread',
      unitPriceMinor: 5000,
    );

    await expectLater(
      database.recordStockMovement(
        context: context,
        productId: product.id,
        type: StockMovementType.damage,
        quantityDeltaMilli: -1000,
      ),
      throwsArgumentError,
    );
  });
}
