import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('credit sale and partial collection preserve immutable balance', () async {
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
    final customer = await database.addCustomer(name: 'Ramesh');
    final product = await database.addProduct(
      name: 'Groceries',
      unitPriceMinor: 85000,
    );

    await database.finalizeCustomerCreditSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      customerId: customer.id,
      dueDate: DateTime.utc(2026, 9, 30),
    );

    var customers = await database.listCustomers();
    expect(customers.single.creditBalanceMinor, 85000);
    expect(await database.customerCreditEntryCount(customer.id), 1);

    await database.collectCustomerCredit(
      context: context,
      customerId: customer.id,
      amountMinor: 30000,
    );

    customers = await database.listCustomers();
    expect(customers.single.creditBalanceMinor, 55000);
    expect(await database.customerCreditEntryCount(customer.id), 2);
  });

  test('collection cannot exceed outstanding customer credit', () async {
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
    final customer = await database.addCustomer(name: 'Anita');

    await expectLater(
      database.collectCustomerCredit(
        context: context,
        customerId: customer.id,
        amountMinor: 100,
      ),
      throwsStateError,
    );
  });
}
