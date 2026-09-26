import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/return_domain.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  LocalSaleContext employeeContext(
    LocalSaleContext owner,
    LocalEmployee employee,
  ) {
    return LocalSaleContext(
      organizationId: owner.organizationId,
      businessId: owner.businessId,
      storeId: owner.storeId,
      terminalId: owner.terminalId,
      userId: employee.id,
      businessName: owner.businessName,
      storeName: owner.storeName,
      terminalCode: owner.terminalCode,
      taxMode: owner.taxMode,
      preferredLocaleCode: owner.preferredLocaleCode,
    );
  }

  test('approved high-value cashier refund is consumed exactly once', () async {
    final database = LocalPosDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await database.open();
    final owner = await database.bootstrapOwner(
      businessName: 'Aaraa Demo Shop',
      storeName: 'Main Store',
    );
    final cashier = await database.addEmployee(
      context: owner,
      name: 'Cashier One',
      role: EmployeeRole.cashier,
    );
    final cashierContext = employeeContext(owner, cashier);

    final product = await database.addProduct(
      name: 'Premium Item',
      unitPriceMinor: 600000,
    );
    final sale = await database.finalizeCashSale(
      context: cashierContext,
      lines: [SaleLineInput(product: product, quantityMilli: 2000)],
      tenderedMinor: 1200000,
    );

    final returnable = (await database.listReturnableSales())
        .singleWhere((item) => item.saleId == sale.saleId);
    final line = returnable.lines.single;
    final request = ReturnLineRequest(
      saleLineId: line.saleLineId,
      quantityMilli: 1000,
    );
    final fingerprint = buildApprovalFingerprint(
      actionType: 'refund',
      entityId: sale.saleId,
      facts: [
        '${line.saleLineId}:1000',
        'amount:600000',
      ],
    );

    final approvalId = await database.requestApproval(
      context: cashierContext,
      actionType: 'refund',
      entityType: 'sale',
      entityId: sale.saleId,
      actionFingerprint: fingerprint,
      requestedAmountMinor: 600000,
      reason: 'Customer return',
    );

    await database.resolveApprovalRequest(
      context: owner,
      approvalRequestId: approvalId,
      approve: true,
    );

    final first = await database.processReturn(
      context: cashierContext,
      saleId: sale.saleId,
      requests: [request],
      reason: 'Customer return',
    );
    expect(first.refundMinor, 600000);

    final approvals = await database.listApprovalRequests(
      context: owner,
      status: LocalApprovalStatus.approved,
    );
    final used = approvals.singleWhere((item) => item.id == approvalId);
    expect(used.consumed, isTrue);
    expect(used.consumedAt, isNotNull);

    await expectLater(
      database.processReturn(
        context: cashierContext,
        saleId: sale.saleId,
        requests: [request],
        reason: 'Second identical partial return',
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Manager approval'),
        ),
      ),
    );
  });

  test('cashier cannot resolve an approval request', () async {
    final database = LocalPosDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await database.open();
    final owner = await database.bootstrapOwner(
      businessName: 'Aaraa Demo Shop',
      storeName: 'Main Store',
    );
    final cashier = await database.addEmployee(
      context: owner,
      name: 'Cashier One',
      role: EmployeeRole.cashier,
    );
    final cashierContext = employeeContext(owner, cashier);

    final approvalId = await database.requestApproval(
      context: cashierContext,
      actionType: 'refund',
      entityType: 'sale',
      entityId: 'sale-1',
      actionFingerprint: buildApprovalFingerprint(
        actionType: 'refund',
        entityId: 'sale-1',
        facts: const ['line-1:1000', 'amount:600000'],
      ),
      requestedAmountMinor: 600000,
      reason: 'High-value refund',
    );

    await expectLater(
      database.resolveApprovalRequest(
        context: cashierContext,
        approvalRequestId: approvalId,
        approve: true,
      ),
      throwsStateError,
    );
  });

  test('requester cannot self-approve even with owner role', () async {
    final database = LocalPosDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await database.open();
    final owner = await database.bootstrapOwner(
      businessName: 'Aaraa Demo Shop',
      storeName: 'Main Store',
    );

    final approvalId = await database.requestApproval(
      context: owner,
      actionType: 'cash_variance',
      entityType: 'shift',
      entityId: 'shift-1',
      reason: 'Review cash difference',
    );

    await expectLater(
      database.resolveApprovalRequest(
        context: owner,
        approvalRequestId: approvalId,
        approve: true,
      ),
      throwsStateError,
    );
  });
}
