import 'package:aaraapos_pos/auth/local_auth_domain.dart';
import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('owner PIN locks after failures then creates restorable session', () async {
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
    final configuredAt = DateTime.utc(2026, 9, 28, 2);

    await database.configureLocalPin(
      context: context,
      employeeId: context.userId,
      pin: '2468',
      iterations: 10000,
      now: configuredAt,
    );

    expect(await database.configuredLocalCredentialCount(), 1);
    expect(await database.hasConfiguredLocalCredential(context.userId), isTrue);
    expect(await database.listSignInEmployees(), hasLength(1));

    for (var attempt = 1; attempt <= 4; attempt++) {
      await expectLater(
        database.authenticateLocalEmployee(
          baseContext: context,
          employeeId: context.userId,
          pin: '1111',
          now: configuredAt.add(Duration(seconds: attempt)),
        ),
        throwsA(
          isA<LocalPinAuthException>().having(
            (error) => error.code,
            'code',
            'PIN_INCORRECT',
          ),
        ),
      );
    }

    await expectLater(
      database.authenticateLocalEmployee(
        baseContext: context,
        employeeId: context.userId,
        pin: '1111',
        now: configuredAt.add(const Duration(seconds: 5)),
      ),
      throwsA(
        isA<LocalPinAuthException>().having(
          (error) => error.code,
          'code',
          'PIN_LOCKED',
        ),
      ),
    );

    await expectLater(
      database.authenticateLocalEmployee(
        baseContext: context,
        employeeId: context.userId,
        pin: '2468',
        now: configuredAt.add(const Duration(minutes: 1)),
      ),
      throwsA(
        isA<LocalPinAuthException>().having(
          (error) => error.code,
          'code',
          'PIN_LOCKED',
        ),
      ),
    );

    final signedInAt = configuredAt.add(const Duration(minutes: 6));
    final session = await database.authenticateLocalEmployee(
      baseContext: context,
      employeeId: context.userId,
      pin: '2468',
      now: signedInAt,
      sessionTtl: const Duration(hours: 2),
    );

    expect(session.context.userId, context.userId);
    expect(session.role, EmployeeRole.owner);
    expect(session.expiresAt, signedInAt.add(const Duration(hours: 2)));

    final restored = await database.restoreLocalSession(
      baseContext: context,
      now: signedInAt.add(const Duration(hours: 1)),
    );
    expect(restored?.context.userId, context.userId);

    await database.endLocalSession(
      context: session.context,
      now: signedInAt.add(const Duration(hours: 1)),
    );
    expect(
      await database.restoreLocalSession(
        baseContext: context,
        now: signedInAt.add(const Duration(hours: 1, minutes: 1)),
      ),
      isNull,
    );

    final outbox = await database.listOutboxItems();
    expect(
      outbox.any((item) => item.entityType == 'employee_local_credential'),
      isFalse,
    );
  });

  test('owner can provision cashier PIN and cashier session changes actor', () async {
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

    await database.configureLocalPin(
      context: owner,
      employeeId: cashier.id,
      pin: '4321',
      iterations: 10000,
      now: DateTime.utc(2026, 9, 28, 2),
    );

    final session = await database.authenticateLocalEmployee(
      baseContext: owner,
      employeeId: cashier.id,
      pin: '4321',
      now: DateTime.utc(2026, 9, 28, 2, 1),
    );

    expect(session.context.userId, cashier.id);
    expect(session.employeeName, 'Cashier One');
    expect(session.role, EmployeeRole.cashier);
  });

  test('manager cannot configure Owner or another Manager PIN', () async {
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
    final managerOne = await database.addEmployee(
      context: owner,
      name: 'Manager One',
      role: EmployeeRole.manager,
    );
    final managerTwo = await database.addEmployee(
      context: owner,
      name: 'Manager Two',
      role: EmployeeRole.manager,
    );
    final cashier = await database.addEmployee(
      context: owner,
      name: 'Cashier One',
      role: EmployeeRole.cashier,
    );

    final managerContext = LocalSaleContext(
      organizationId: owner.organizationId,
      businessId: owner.businessId,
      storeId: owner.storeId,
      terminalId: owner.terminalId,
      userId: managerOne.id,
      businessName: owner.businessName,
      storeName: owner.storeName,
      terminalCode: owner.terminalCode,
      taxMode: owner.taxMode,
      preferredLocaleCode: owner.preferredLocaleCode,
    );

    await expectLater(
      database.configureLocalPin(
        context: managerContext,
        employeeId: owner.userId,
        pin: '2468',
        iterations: 10000,
      ),
      throwsStateError,
    );
    await expectLater(
      database.configureLocalPin(
        context: managerContext,
        employeeId: managerTwo.id,
        pin: '2468',
        iterations: 10000,
      ),
      throwsStateError,
    );

    await database.configureLocalPin(
      context: managerContext,
      employeeId: managerOne.id,
      pin: '1357',
      iterations: 10000,
    );
    await database.configureLocalPin(
      context: managerContext,
      employeeId: cashier.id,
      pin: '4321',
      iterations: 10000,
    );

    expect(
      await database.hasConfiguredLocalCredential(managerOne.id),
      isTrue,
    );
    expect(
      await database.hasConfiguredLocalCredential(cashier.id),
      isTrue,
    );
  });

  test('expired local session is discarded', () async {
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
    await database.configureLocalPin(
      context: owner,
      employeeId: owner.userId,
      pin: '2468',
      iterations: 10000,
      now: DateTime.utc(2026, 9, 28, 2),
    );
    await database.authenticateLocalEmployee(
      baseContext: owner,
      employeeId: owner.userId,
      pin: '2468',
      now: DateTime.utc(2026, 9, 28, 2),
      sessionTtl: const Duration(minutes: 30),
    );

    expect(
      await database.restoreLocalSession(
        baseContext: owner,
        now: DateTime.utc(2026, 9, 28, 2, 31),
      ),
      isNull,
    );
  });
}
