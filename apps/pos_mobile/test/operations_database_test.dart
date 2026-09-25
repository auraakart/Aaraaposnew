import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('shift reconciles cash activity and creates variance approval', () async {
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

    final employees = await database.listEmployees();
    expect(employees.single.role, EmployeeRole.owner);

    await database.openShift(
      context: context,
      employeeId: employees.single.id,
      openingCashMinor: 50000,
    );

    final product = await database.addProduct(
      name: 'Milk',
      unitPriceMinor: 10000,
    );
    await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 10000,
    );

    await database.recordCashMovement(
      context: context,
      movementType: 'deposit',
      amountMinor: 5000,
      reason: 'Add change',
    );
    await database.recordCashMovement(
      context: context,
      movementType: 'withdrawal',
      amountMinor: 2000,
      reason: 'Safe drop',
    );
    await database.addExpense(
      context: context,
      category: 'Tea/Food',
      amountMinor: 3000,
      paymentMethod: 'cash',
    );

    final closed = await database.closeShift(
      context: context,
      actualClosingCashMinor: 59400,
      varianceApprovalThresholdMinor: 500,
    );

    expect(closed.expectedClosingCashMinor, 60000);
    expect(closed.varianceMinor, -600);
    expect(await database.pendingApprovalCount(), 1);
    expect(await database.currentShift(), isNull);
  });

  test('only one shift can be open', () async {
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
    final employee = (await database.listEmployees()).single;

    await database.openShift(
      context: context,
      employeeId: employee.id,
      openingCashMinor: 0,
    );

    await expectLater(
      database.openShift(
        context: context,
        employeeId: employee.id,
        openingCashMinor: 0,
      ),
      throwsStateError,
    );
  });
}
