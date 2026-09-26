import 'package:aaraapos_pos/diagnostics/diagnostics_domain.dart';
import 'package:aaraapos_pos/recovery/recovery_readiness.dart';
import 'package:aaraapos_pos/sync/sync_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('healthy synced local state can be assessed but not externally backed up',
      () {
    final readiness = RecoveryReadiness.fromDiagnostics(
      LocalDiagnosticsSnapshot(
        generatedAt: DateTime.utc(2026, 9, 26, 10),
        databaseIntegrityOk: true,
        foreignKeysEnabled: true,
        schemaVersion: 12,
        outboxCounts: const {
          LocalSyncState.pending: 0,
          LocalSyncState.sending: 0,
          LocalSyncState.acknowledged: 4,
          LocalSyncState.conflict: 0,
          LocalSyncState.rejected: 0,
        },
        productCount: 2,
        finalizedSaleCount: 2,
        auditEventCount: 2,
        openShiftCount: 0,
      ),
    );

    expect(readiness.canEvaluateRestoreSafely, isTrue);
    expect(readiness.canCreateExternalBackup, isFalse);
    expect(readiness.blockers, ['BACKUP_PROVIDER_NOT_CONFIGURED']);
  });

  test('unsynced writes block restore assessment', () {
    final readiness = RecoveryReadiness.fromDiagnostics(
      LocalDiagnosticsSnapshot(
        generatedAt: DateTime.utc(2026, 9, 26, 10),
        databaseIntegrityOk: true,
        foreignKeysEnabled: true,
        schemaVersion: 12,
        outboxCounts: const {
          LocalSyncState.pending: 2,
          LocalSyncState.conflict: 1,
        },
        productCount: 0,
        finalizedSaleCount: 0,
        auditEventCount: 0,
        openShiftCount: 0,
      ),
      backupProviderConfigured: true,
    );

    expect(readiness.canEvaluateRestoreSafely, isFalse);
    expect(readiness.canCreateExternalBackup, isTrue);
    expect(readiness.blockers, contains('UNRESOLVED_LOCAL_WRITES'));
  });

  test('database integrity failure blocks all recovery confidence', () {
    const readiness = RecoveryReadiness(
      databaseHealthy: false,
      foreignKeysEnabled: true,
      unresolvedLocalWrites: 0,
      schemaVersion: 12,
      backupProviderConfigured: true,
    );

    expect(readiness.canEvaluateRestoreSafely, isFalse);
    expect(readiness.canCreateExternalBackup, isFalse);
    expect(
      readiness.blockers,
      contains('LOCAL_DATABASE_INTEGRITY_FAILED'),
    );
  });
}
