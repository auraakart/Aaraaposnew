import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('purchase receipt increases stock and creates supplier payable', () async {
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
      name: 'Rice',
      unitPriceMinor: 12000,
    );
    final supplier = await database.addSupplier(name: 'City Wholesalers');

    final orderId = await database.createPurchaseOrder(
      context: context,
      supplierId: supplier.id,
      productId: product.id,
      quantityMilli: 10000,
      unitCostMinor: 8000,
    );

    await database.receivePurchaseOrder(
      context: context,
      purchaseOrderId: orderId,
    );

    final inventory = await database.listInventory();
    expect(inventory.single.onHandMilli, 10000);

    var suppliers = await database.listSuppliers();
    expect(suppliers.single.balanceMinor, 80000);

    final orders = await database.listPurchaseOrders();
    expect(orders.single.status, 'received');

    await database.paySupplier(
      context: context,
      supplierId: supplier.id,
      amountMinor: 30000,
    );

    suppliers = await database.listSuppliers();
    expect(suppliers.single.balanceMinor, 50000);

    await database.recordPurchaseReturn(
      context: context,
      supplierId: supplier.id,
      productId: product.id,
      quantityMilli: 2000,
      creditMinor: 16000,
      reason: 'Damaged shipment',
    );

    final updatedInventory = await database.listInventory();
    expect(updatedInventory.single.onHandMilli, 8000);

    suppliers = await database.listSuppliers();
    expect(suppliers.single.balanceMinor, 34000);

    final ledger = await database.supplierLedgerEntries(supplier.id);
    expect(ledger.length, 3);
    final outbox = await database.listOutboxItems();
    expect(
      outbox.where((item) => item.entityType != 'audit_event').length,
      4,
    );
    expect(
      outbox.where((item) => item.entityType == 'audit_event').length,
      1,
    );
  });

  test('supplier payment cannot exceed payable balance', () async {
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
    final supplier = await database.addSupplier(name: 'No Balance Supplier');

    await expectLater(
      database.paySupplier(
        context: context,
        supplierId: supplier.id,
        amountMinor: 100,
      ),
      throwsStateError,
    );
  });
}
