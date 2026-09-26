import '../sync/sync_domain.dart';

class LocalDiagnosticsSnapshot {
  const LocalDiagnosticsSnapshot({
    required this.generatedAt,
    required this.databaseIntegrityOk,
    required this.foreignKeysEnabled,
    required this.schemaVersion,
    required this.outboxCounts,
    required this.productCount,
    required this.finalizedSaleCount,
    required this.auditEventCount,
    required this.openShiftCount,
    this.oldestUnresolvedAt,
  });

  final DateTime generatedAt;
  final bool databaseIntegrityOk;
  final bool foreignKeysEnabled;
  final int schemaVersion;
  final Map<LocalSyncState, int> outboxCounts;
  final int productCount;
  final int finalizedSaleCount;
  final int auditEventCount;
  final int openShiftCount;
  final DateTime? oldestUnresolvedAt;

  int get unresolvedSyncCount =>
      (outboxCounts[LocalSyncState.pending] ?? 0) +
      (outboxCounts[LocalSyncState.sending] ?? 0) +
      (outboxCounts[LocalSyncState.conflict] ?? 0) +
      (outboxCounts[LocalSyncState.rejected] ?? 0);

  Duration? unresolvedAge(DateTime now) {
    final oldest = oldestUnresolvedAt;
    if (oldest == null) return null;
    final age = now.toUtc().difference(oldest.toUtc());
    return age.isNegative ? Duration.zero : age;
  }

  bool get needsAttention =>
      !databaseIntegrityOk ||
      !foreignKeysEnabled ||
      (outboxCounts[LocalSyncState.conflict] ?? 0) > 0 ||
      (outboxCounts[LocalSyncState.rejected] ?? 0) > 0;
}
