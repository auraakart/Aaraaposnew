import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('preferred locale persists in local context', () async {
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

    expect((await database.loadContext())?.preferredLocaleCode, isNull);

    await database.updatePreferredLocaleCode('ta');
    expect((await database.loadContext())?.preferredLocaleCode, 'ta');

    await database.updatePreferredLocaleCode(null);
    expect((await database.loadContext())?.preferredLocaleCode, isNull);

    await expectLater(
      database.updatePreferredLocaleCode('te'),
      throwsArgumentError,
    );
  });
}
