import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('offline cash sale is durable and queued exactly once', () async {
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
      unitPriceMinor: 42700,
      barcode: '890000000001',
    );

    final first = await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 50000,
    );

    expect(first.invoiceNumber, 'T01-000001');
    expect(first.totalMinor, 42700);
    expect(first.changeMinor, 7300);
    expect(first.receiptText, contains('Milk'));
    var outbox = await database.listOutboxItems();
    expect(
      outbox.where((item) => item.entityType == 'sale').length,
      1,
    );
    expect(
      outbox.where((item) => item.entityType == 'audit_event').length,
      1,
    );
    expect(await database.paymentEventCountForSale(first.saleId), 1);

    final second = await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 42700,
    );

    expect(second.invoiceNumber, 'T01-000002');
    outbox = await database.listOutboxItems();
    expect(
      outbox.where((item) => item.entityType == 'sale').length,
      2,
    );
    expect(
      outbox.where((item) => item.entityType == 'audit_event').length,
      2,
    );
  });
}
