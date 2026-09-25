import 'package:aaraapos_pos/payments/payment_domain.dart';
import 'package:aaraapos_pos/payments/payment_method_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unconfigured UPI card and split payment remain disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showPaymentMethodSheet(
                context,
                availableMethods: const {PaymentMethod.cash},
                splitEnabled: false,
              ),
              child: const Text('Pay'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();

    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('Card'), findsOneWidget);
    expect(find.text('Split payment'), findsOneWidget);
    expect(
      find.text('Connect a payment provider to enable UPI.'),
      findsOneWidget,
    );
    expect(
      find.text('Connect a payment provider to enable cards.'),
      findsOneWidget,
    );
  });

  testWidgets('cash choice returns only when enabled', (tester) async {
    PaymentChoice? choice;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                choice = await showPaymentMethodSheet(
                  context,
                  availableMethods: const {PaymentMethod.cash},
                  splitEnabled: false,
                );
              },
              child: const Text('Pay'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Pay'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();

    expect(choice, PaymentChoice.cash);
  });
}
