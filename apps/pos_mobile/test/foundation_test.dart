import 'package:aaraapos_pos/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('foundation exposes five primary navigation destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const AaraaPosApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Sell'), findsOneWidget);
    expect(find.text('Stock'), findsOneWidget);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);
  });

  test('financial sync envelopes never permit last-write-wins', () {
    final envelope = SyncEnvelope(
      id: 'event-1',
      organizationId: 'org-1',
      businessId: 'business-1',
      storeId: 'store-1',
      terminalId: 'terminal-1',
      idempotencyKey: 'idem-1',
      createdAt: DateTime.utc(2026, 9, 25),
      state: SyncState.pending,
      conflictPolicy: ConflictPolicy.appendOnlyFinancial,
      schemaVersion: 1,
    );

    expect(envelope.permitsLastWriteWins, isFalse);
  });
}
