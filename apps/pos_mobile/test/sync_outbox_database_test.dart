import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:aaraapos_pos/sync/sync_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('sale outbox transitions through sending and acknowledgement', () async {
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
      unitPriceMinor: 10000,
    );

    await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 10000,
    );

    final pending = await database.listOutboxItems();
    final saleItem = pending.firstWhere((item) => item.entityType == 'sale');
    expect(saleItem.state, LocalSyncState.pending);
    expect(saleItem.schemaVersion, 1);

    await database.markOutboxSending(saleItem.id);
    final sending = (await database.listOutboxItems())
        .firstWhere((item) => item.id == saleItem.id);
    expect(sending.state, LocalSyncState.sending);
    expect(sending.attemptCount, 1);
    expect(sending.lastAttemptAt, isNotNull);

    await database.applySyncAcknowledgement(
      LocalSyncAcknowledgement(
        idempotencyKey: saleItem.idempotencyKey,
        entityId: saleItem.entityId,
        state: LocalSyncState.acknowledged,
      ),
    );

    final all = await database.listOutboxItems(unresolvedOnly: false);
    final acknowledged = all.firstWhere((item) => item.id == saleItem.id);
    expect(acknowledged.state, LocalSyncState.acknowledged);
    expect(
      (await database.listOutboxItems())
          .where((item) => item.id == saleItem.id),
      isEmpty,
    );
  });

  test('conflicted outbox item can be retried without losing evidence', () async {
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
      name: 'Bread',
      unitPriceMinor: 5000,
    );

    await database.finalizeCashSale(
      context: context,
      lines: [SaleLineInput(product: product, quantityMilli: 1000)],
      tenderedMinor: 5000,
    );

    final item = (await database.listOutboxItems())
        .firstWhere((value) => value.entityType == 'sale');
    await database.markOutboxSending(item.id);
    await database.applySyncAcknowledgement(
      LocalSyncAcknowledgement(
        idempotencyKey: item.idempotencyKey,
        entityId: item.entityId,
        state: LocalSyncState.conflict,
        code: 'SERVER_VERSION_CONFLICT',
        message: 'Server version changed.',
      ),
    );

    var current = (await database.listOutboxItems())
        .firstWhere((value) => value.id == item.id);
    expect(current.state, LocalSyncState.conflict);
    expect(current.serverMessage, 'Server version changed.');

    await database.retryOutbox(item.id);
    current = (await database.listOutboxItems())
        .firstWhere((value) => value.id == item.id);
    expect(current.state, LocalSyncState.pending);
    expect(current.serverMessage, isNull);
    expect(current.attemptCount, 1);
  });
}
