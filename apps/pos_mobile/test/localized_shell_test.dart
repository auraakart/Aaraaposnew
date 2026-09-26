import 'package:aaraapos_pos/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Hindi locale renders through the application delegate',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Text(AppStrings.of(context).businessToday),
                Text(AppStrings.of(context).sell),
                Text(AppStrings.of(context).customers),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('आज का कारोबार'), findsOneWidget);
    expect(find.text('बिक्री'), findsOneWidget);
    expect(find.text('ग्राहक'), findsOneWidget);
  });
}
