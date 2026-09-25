import 'package:aaraapos_pos/commerce/commerce_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('commerce order is pre-sale until normal checkout completes', () async {
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
    final customer = await database.addCustomer(
      name: 'Ramesh',
      mobile: '+919999999999',
    );
    final milk = await database.addProduct(
      name: 'Milk',
      unitPriceMinor: 6000,
    );
    final bread = await database.addProduct(
      name: 'Bread',
      unitPriceMinor: 4000,
    );

    final orderId = await database.createCommerceOrder(
      context: context,
      channel: CommerceChannel.whatsapp,
      customerId: customer.id,
      externalConversationRef: 'manual-wa-1',
      lines: [
        SaleLineInput(product: milk, quantityMilli: 2000),
        SaleLineInput(product: bread, quantityMilli: 1000),
      ],
    );

    var order = (await database.listCommerceOrders())
        .singleWhere((item) => item.id == orderId);
    expect(order.status, CommerceOrderStatus.received);
    expect(order.saleId, isNull);
    expect(order.quotedTotalMinor, 16000);
    expect(order.lines.length, 2);

    await database.transitionCommerceOrder(
      context: context,
      orderId: orderId,
      action: 'confirm',
    );

    order = (await database.listCommerceOrders())
        .singleWhere((item) => item.id == orderId);
    final sale = await database.finalizeCashSale(
      context: context,
      lines: order.lines.map((line) => line.toSaleLine()).toList(),
      tenderedMinor: 20000,
      customerId: order.customer?.id,
    );

    await database.completeCommerceOrder(
      context: context,
      orderId: orderId,
      saleId: sale.saleId,
    );

    order = (await database.listCommerceOrders())
        .singleWhere((item) => item.id == orderId);
    expect(order.status, CommerceOrderStatus.completed);
    expect(order.saleId, sale.saleId);
    expect(sale.totalMinor, 16000);
  });

  test('cancelled order cannot be linked to a sale', () async {
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
      unitPriceMinor: 6000,
    );
    final orderId = await database.createCommerceOrder(
      context: context,
      channel: CommerceChannel.phone,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
    );
    await database.transitionCommerceOrder(
      context: context,
      orderId: orderId,
      action: 'cancel',
    );

    final sale = await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 6000,
    );

    expect(
      () => database.completeCommerceOrder(
        context: context,
        orderId: orderId,
        saleId: sale.saleId,
      ),
      throwsA(isA<StateError>()),
    );
  });
}
