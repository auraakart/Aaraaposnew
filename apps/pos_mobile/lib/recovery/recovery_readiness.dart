import '../diagnostics/diagnostics_domain.dart';

class RecoveryReadiness {
  const RecoveryReadiness({
    required this.databaseHealthy,
    required this.foreignKeysEnabled,
    required this.unresolvedLocalWrites,
    required this.schemaVersion,
    required this.backupProviderConfigured,
  });

  final bool databaseHealthy;
  final bool foreignKeysEnabled;
  final int unresolvedLocalWrites;
  final int schemaVersion;
  final bool backupProviderConfigured;

  bool get canEvaluateRestoreSafely =>
      databaseHealthy &&
      foreignKeysEnabled &&
      unresolvedLocalWrites == 0;

  bool get canCreateExternalBackup =>
      databaseHealthy &&
      foreignKeysEnabled &&
      backupProviderConfigured;

  List<String> get blockers {
    final result = <String>[];
    if (!databaseHealthy) result.add('LOCAL_DATABASE_INTEGRITY_FAILED');
    if (!foreignKeysEnabled) result.add('FOREIGN_KEYS_DISABLED');
    if (unresolvedLocalWrites > 0) {
      result.add('UNRESOLVED_LOCAL_WRITES');
    }
    if (!backupProviderConfigured) {
      result.add('BACKUP_PROVIDER_NOT_CONFIGURED');
    }
    return result;
  }

  static RecoveryReadiness fromDiagnostics(
    LocalDiagnosticsSnapshot snapshot, {
    bool backupProviderConfigured = false,
  }) {
    return RecoveryReadiness(
      databaseHealthy: snapshot.databaseIntegrityOk,
      foreignKeysEnabled: snapshot.foreignKeysEnabled,
      unresolvedLocalWrites: snapshot.unresolvedSyncCount,
      schemaVersion: snapshot.schemaVersion,
      backupProviderConfigured: backupProviderConfigured,
    );
  }
}
