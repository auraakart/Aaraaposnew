import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sell_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('cart keeps product snapshots when search results change', (
    tester,
  ) async {
    final database = LocalPosDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    addTearDown(database.close);

    await tester.runAsync(() async {
      await database.open();
      await database.bootstrapOwner(
        businessName: 'Aaraa Demo Shop',
        storeName: 'Main Store',
      );
      await database.addProduct(name: 'Milk', unitPriceMinor: 10000);
      await database.addProduct(name: 'Bread', unitPriceMinor: 5000);
    });
    final saleContext = await tester.runAsync(database.loadContext);
    expect(saleContext, isNotNull);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SellScreen(
            database: database,
            saleContext: saleContext!,
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    await tester.tap(find.text('Milk'));
    await tester.pump();
    expect(find.text('Pay ₹100.00'), findsOneWidget);

    final search = tester.widget<SearchBar>(find.byType(SearchBar));
    search.onSubmitted?.call('Bread');
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();

    expect(find.text('Milk'), findsNothing);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Pay ₹100.00'), findsOneWidget);
  });
}
