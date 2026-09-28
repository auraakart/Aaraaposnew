import 'package:aaraapos_pos/l10n/app_strings.dart';
import 'package:aaraapos_pos/more/more_screen.dart';
import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:aaraapos_pos/sell/local_pos_database.dart';
import 'package:aaraapos_pos/sell/sale_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const saleContext = LocalSaleContext(
    organizationId: 'org-1',
    businessId: 'business-1',
    storeId: 'store-1',
    terminalId: 'terminal-1',
    userId: 'employee-1',
    businessName: 'Aaraa Demo Shop',
    storeName: 'Main Store',
    terminalCode: 'T01',
    taxMode: TaxMode.intraState,
  );

  Widget appFor(EmployeeRole role) {
    return MaterialApp(
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: MoreScreen(
          database: LocalPosDatabase(),
          saleContext: saleContext,
          role: role,
        ),
      ),
    );
  }

  testWidgets('Cashier More hides administrative and accounting surfaces',
      (tester) async {
    await tester.pumpWidget(appFor(EmployeeRole.cashier));
    await tester.pump();

    expect(find.text('Language & Accessibility'), findsOneWidget);
    expect(find.text('Hardware & Devices'), findsOneWidget);

    expect(find.text('Employee Access'), findsNothing);
    expect(find.text('Recovery Readiness'), findsNothing);
    expect(find.text('Diagnostics'), findsNothing);
    expect(find.text('Audit History'), findsNothing);
    expect(find.text('Accounting Export'), findsNothing);
    expect(find.text('Integrations & Sync'), findsNothing);
    expect(find.text('Loyalty & Offers'), findsNothing);
    expect(find.text('Purchases & Suppliers'), findsNothing);
  });

  testWidgets('Stock Worker More contains only safe operational settings',
      (tester) async {
    await tester.pumpWidget(appFor(EmployeeRole.stockWorker));
    await tester.pump();

    expect(find.text('Language & Accessibility'), findsOneWidget);
    expect(find.text('Hardware & Devices'), findsOneWidget);
    expect(find.text('Store & Terminal'), findsOneWidget);

    expect(find.text('Employee Access'), findsNothing);
    expect(find.text('Commerce Orders'), findsNothing);
    expect(find.text('Returns & Refunds'), findsNothing);
    expect(find.text('Store Operations'), findsNothing);
    expect(find.text('Purchases & Suppliers'), findsNothing);
    expect(find.text('Accounting Export'), findsNothing);
  });
}
