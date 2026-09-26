import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/return_domain.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('critical actions append source-linked audit events', () async {
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

    final sale = await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 6000,
    );
    await database.addExpense(
      context: context,
      category: 'Transport',
      amountMinor: 500,
      paymentMethod: 'upi',
    );
    final employee = await database.addEmployee(
      context: context,
      name: 'Cashier One',
      role: EmployeeRole.cashier,
    );

    final returnable = (await database.listReturnableSales())
        .singleWhere((item) => item.saleId == sale.saleId);
    final returned = await database.processReturn(
      context: context,
      saleId: sale.saleId,
      requests: [
        ReturnLineRequest(
          saleLineId: returnable.lines.single.saleLineId,
          quantityMilli: 1000,
        ),
      ],
      reason: 'Customer return',
    );

    final events = await database.listAuditEvents();
    final actions = events.map((event) => event.action).toSet();

    expect(actions, contains('sale.finalized'));
    expect(actions, contains('sale.returned'));
    expect(actions, contains('expense.recorded'));
    expect(actions, contains('employee.created'));

    final saleAudit =
        events.singleWhere((event) => event.action == 'sale.finalized');
    expect(saleAudit.entityType, 'sale');
    expect(saleAudit.entityId, sale.saleId);
    expect(saleAudit.metadata['reference'], sale.invoiceNumber);
    expect(saleAudit.outcome, 'success');

    final returnAudit =
        events.singleWhere((event) => event.action == 'sale.returned');
    expect(returnAudit.entityId, returned.returnId);
    expect(returnAudit.metadata['saleId'], sale.saleId);

    final cashierContext = LocalSaleContext(
      organizationId: context.organizationId,
      businessId: context.businessId,
      storeId: context.storeId,
      terminalId: context.terminalId,
      userId: employee.id,
      businessName: context.businessName,
      storeName: context.storeName,
      terminalCode: context.terminalCode,
      taxMode: context.taxMode,
      preferredLocaleCode: context.preferredLocaleCode,
    );

    expect(await database.canReadAudit(context), isTrue);
    expect(await database.canReadAudit(cashierContext), isFalse);
  });

  test('audit query rejects unbounded history requests', () async {
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
      database.listAuditEvents(limit: 1001),
      throwsArgumentError,
    );
  });
}
