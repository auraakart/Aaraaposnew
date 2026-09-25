import 'package:aaraapos_pos/main.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('first-run owner can create a local store and reach Sell', (
    tester,
  ) async {
    final database = LocalPosDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await tester.runAsync(database.open);
    await tester.pumpWidget(AaraaPosApp(database: database));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('Start billing in minutes'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Aaraa Demo Shop');
    await tester.tap(find.text('Create store'));
    await tester.pump();

    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20; attempt++) {
        if (await database.loadContext() != null) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      throw StateError('Store bootstrap did not complete');
    });
    await tester.pump();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sell'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    await tester.tap(find.text('Sell'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(
      find.text('No products yet. Tap + to add your first product.'),
      findsOneWidget,
    );
  });
}
