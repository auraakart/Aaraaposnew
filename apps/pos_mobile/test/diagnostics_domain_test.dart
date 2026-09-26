import 'package:aaraapos_pos/diagnostics/diagnostics_domain.dart';
import 'package:aaraapos_pos/sync/sync_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('diagnostics flags database or sync conflicts as attention', () {
    final healthy = LocalDiagnosticsSnapshot(
      generatedAt: DateTime.utc(2026, 9, 26, 10),
      databaseIntegrityOk: true,
      foreignKeysEnabled: true,
      schemaVersion: 12,
      outboxCounts: const {
        LocalSyncState.pending: 1,
        LocalSyncState.sending: 0,
        LocalSyncState.acknowledged: 3,
        LocalSyncState.conflict: 0,
        LocalSyncState.rejected: 0,
      },
      productCount: 3,
      finalizedSaleCount: 2,
      auditEventCount: 2,
      openShiftCount: 0,
      oldestUnresolvedAt: DateTime.utc(2026, 9, 26, 9, 30),
    );

    expect(healthy.needsAttention, isFalse);
    expect(healthy.unresolvedSyncCount, 1);
    expect(
      healthy.unresolvedAge(DateTime.utc(2026, 9, 26, 10)),
      const Duration(minutes: 30),
    );

    final conflict = LocalDiagnosticsSnapshot(
      generatedAt: healthy.generatedAt,
      databaseIntegrityOk: true,
      foreignKeysEnabled: true,
      schemaVersion: 12,
      outboxCounts: const {
        LocalSyncState.pending: 0,
        LocalSyncState.sending: 0,
        LocalSyncState.acknowledged: 0,
        LocalSyncState.conflict: 1,
        LocalSyncState.rejected: 0,
      },
      productCount: 0,
      finalizedSaleCount: 0,
      auditEventCount: 0,
      openShiftCount: 0,
    );

    expect(conflict.needsAttention, isTrue);
  });

  test('future unresolved timestamps clamp age to zero', () {
    final snapshot = LocalDiagnosticsSnapshot(
      generatedAt: DateTime.utc(2026, 9, 26, 10),
      databaseIntegrityOk: true,
      foreignKeysEnabled: true,
      schemaVersion: 12,
      outboxCounts: const {},
      productCount: 0,
      finalizedSaleCount: 0,
      auditEventCount: 0,
      openShiftCount: 0,
      oldestUnresolvedAt: DateTime.utc(2026, 9, 26, 11),
    );

    expect(
      snapshot.unresolvedAge(DateTime.utc(2026, 9, 26, 10)),
      Duration.zero,
    );
  });
}
