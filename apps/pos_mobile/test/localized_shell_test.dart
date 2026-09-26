import 'package:aaraapos_pos/main.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('persisted Hindi locale renders the core shell in Hindi',
      (tester) async {
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
    await database.updatePreferredLocaleCode('hi');

    await tester.pumpWidget(AaraaPosApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('आज का कारोबार'), findsOneWidget);
    expect(find.text('बिक्री'), findsOneWidget);
    expect(find.text('ग्राहक'), findsOneWidget);
  });
}
