import 'package:aaraapos_pos/inventory/inventory_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/return_domain.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('held bill preserves customer quantity price and discount', () async {
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
    final customer = await database.addCustomer(name: 'Ramesh');
    final product = await database.addProduct(
      name: 'Milk',
      unitPriceMinor: 10000,
    );

    final id = await database.holdSale(
      customerId: customer.id,
      lines: [
        SaleLineInput(
          product: product,
          quantityMilli: 2000,
          discountMinor: 500,
        ),
      ],
    );

    final held = await database.listHeldSales();
    expect(held.single.id, id);
    expect(held.single.customerName, 'Ramesh');
    expect(held.single.lines.single.quantityMilli, 2000);
    expect(held.single.lines.single.discountMinor, 500);

    final resumed = await database.resumeHeldSale(id);
    expect(resumed.lines.single.product.unitPriceMinor, 10000);
    expect(await database.listHeldSales(), isEmpty);
  });

  test('cash return restores stock and is included in shift cash', () async {
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
    final owner = (await database.listEmployees()).single;
    await database.openShift(
      context: context,
      employeeId: owner.id,
      openingCashMinor: 50000,
    );

    final product = await database.addProduct(
      name: 'Milk',
      unitPriceMinor: 10000,
    );
    await database.recordStockMovement(
      context: context,
      productId: product.id,
      type: StockMovementType.receive,
      quantityDeltaMilli: 5000,
    );
    final sale = await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 2000)],
      tenderedMinor: 20000,
    );

    final returnable = (await database.listReturnableSales()).single;
    final result = await database.processReturn(
      context: context,
      saleId: sale.saleId,
      requests: [
        ReturnLineRequest(
          saleLineId: returnable.lines.single.saleLineId,
          quantityMilli: 1000,
        ),
      ],
      reason: 'Customer changed mind',
    );

    expect(result.refundMinor, 10000);
    expect(result.cashRefundMinor, 10000);
    expect(result.creditReversalMinor, 0);
    expect(await database.returnCountForSale(sale.saleId), 1);
    expect((await database.listInventory()).single.onHandMilli, 4000);

    final closed = await database.closeShift(
      context: context,
      actualClosingCashMinor: 60000,
    );
    expect(closed.expectedClosingCashMinor, 60000);
    expect(closed.varianceMinor, 0);
  });

  test('paid portion of Pay Later return becomes cash refund', () async {
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
      name: 'Groceries',
      unitPriceMinor: 85000,
    );
    final customer = await database.addCustomer(name: 'Anita');

    final sale = await database.finalizeCustomerCreditSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      customerId: customer.id,
    );
    await database.collectCustomerCredit(
      context: context,
      customerId: customer.id,
      amountMinor: 30000,
    );

    final returnable = (await database.listReturnableSales()).single;
    final result = await database.processReturn(
      context: context,
      saleId: sale.saleId,
      requests: [
        ReturnLineRequest(
          saleLineId: returnable.lines.single.saleLineId,
          quantityMilli: 1000,
        ),
      ],
      reason: 'Full return',
    );

    expect(result.refundMinor, 85000);
    expect(result.creditReversalMinor, 55000);
    expect(result.cashRefundMinor, 30000);
    expect((await database.listCustomers()).single.creditBalanceMinor, 0);
    expect(await database.listReturnableSales(), isEmpty);
  });
}
