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

    await tester.pumpWidget(AaraaPosApp(database: database));
    await tester.pumpAndSettle();

    expect(find.text('Start billing in minutes'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Business name'),
      'Aaraa Demo Shop',
    );
    await tester.tap(find.text('Create store'));
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sell'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    await tester.tap(find.text('Sell'));
    await tester.pumpAndSettle();
    expect(
      find.text('No products yet. Tap + to add your first product.'),
      findsOneWidget,
    );
  });
}
