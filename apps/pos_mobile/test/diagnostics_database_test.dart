import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:aaraapos_pos/sync/sync_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('diagnostics reports database and sync health without record content',
      () async {
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

    await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 6000,
    );

    final snapshot = await database.diagnosticsSnapshot(
      now: DateTime.utc(2026, 9, 26, 10),
    );

    expect(snapshot.databaseIntegrityOk, isTrue);
    expect(snapshot.foreignKeysEnabled, isTrue);
    expect(snapshot.schemaVersion, greaterThanOrEqualTo(12));
    expect(snapshot.productCount, 1);
    expect(snapshot.finalizedSaleCount, 1);
    expect(snapshot.auditEventCount, 1);
    expect(snapshot.outboxCounts[LocalSyncState.pending], 2);
    expect(snapshot.oldestUnresolvedAt, isNotNull);
    expect(await database.canReadDiagnostics(context), isTrue);
  });

  test('cashier cannot read owner manager diagnostics', () async {
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

    final cashierContext = LocalSaleContext(
      organizationId: owner.organizationId,
      businessId: owner.businessId,
      storeId: owner.storeId,
      terminalId: owner.terminalId,
      userId: cashier.id,
      businessName: owner.businessName,
      storeName: owner.storeName,
      terminalCode: owner.terminalCode,
      taxMode: owner.taxMode,
      preferredLocaleCode: owner.preferredLocaleCode,
    );

    expect(await database.canReadDiagnostics(cashierContext), isFalse);
  });
}
