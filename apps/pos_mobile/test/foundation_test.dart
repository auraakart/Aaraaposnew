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
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 75));
        await database.close();
      });
    });

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

    late LocalSaleContext storeContext;
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 20; attempt++) {
        final context = await database.loadContext();
        if (context != null) {
          storeContext = context;
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      throw StateError('Store bootstrap did not complete');
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Create the Owner PIN'), findsOneWidget);
    final pinFields = find.byType(TextField);
    await tester.enterText(pinFields.first, '2468');
    await tester.enterText(pinFields.last, '2468');
    await tester.tap(find.text('Create PIN & continue'));
    await tester.pump();

    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 60; attempt++) {
        final session = await database.restoreLocalSession(
          baseContext: storeContext,
        );
        if (session != null) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
      throw StateError('Owner sign-in did not complete');
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    for (var attempt = 0;
        attempt < 20 && find.text('Home').evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 25));
    }

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
