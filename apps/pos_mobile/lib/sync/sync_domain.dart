enum LocalSyncState {
  pending,
  sending,
  acknowledged,
  conflict,
  rejected,
}

enum SyncConflictClass {
  appendOnlyFinancial,
  inventoryMovement,
  masterData,
  configurationSecurity,
}

class LocalOutboxItem {
  const LocalOutboxItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.idempotencyKey,
    required this.schemaVersion,
    required this.state,
    required this.createdAt,
    required this.attemptCount,
    this.lastAttemptAt,
    this.serverMessage,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String idempotencyKey;
  final int schemaVersion;
  final LocalSyncState state;
  final DateTime createdAt;
  final int attemptCount;
  final DateTime? lastAttemptAt;
  final String? serverMessage;
}

class LocalSyncAcknowledgement {
  const LocalSyncAcknowledgement({
    required this.idempotencyKey,
    required this.entityId,
    required this.state,
    this.code,
    this.message,
  });

  final String idempotencyKey;
  final String entityId;
  final LocalSyncState state;
  final String? code;
  final String? message;
}

LocalSyncState localSyncStateFromValue(String value) => switch (value) {
      'sending' => LocalSyncState.sending,
      'acknowledged' => LocalSyncState.acknowledged,
      'conflict' => LocalSyncState.conflict,
      'rejected' => LocalSyncState.rejected,
      _ => LocalSyncState.pending,
    };

String localSyncStateValue(LocalSyncState value) => switch (value) {
      LocalSyncState.pending => 'pending',
      LocalSyncState.sending => 'sending',
      LocalSyncState.acknowledged => 'acknowledged',
      LocalSyncState.conflict => 'conflict',
      LocalSyncState.rejected => 'rejected',
    };

LocalSyncState nextLocalSyncState(
  LocalSyncState current,
  String event,
) {
  if (current == LocalSyncState.pending && event == 'send') {
    return LocalSyncState.sending;
  }
  if (current == LocalSyncState.sending && event == 'acknowledge') {
    return LocalSyncState.acknowledged;
  }
  if (current == LocalSyncState.sending && event == 'conflict') {
    return LocalSyncState.conflict;
  }
  if (current == LocalSyncState.sending && event == 'reject') {
    return LocalSyncState.rejected;
  }
  if ((current == LocalSyncState.sending ||
          current == LocalSyncState.conflict ||
          current == LocalSyncState.rejected) &&
      event == 'retry') {
    return LocalSyncState.pending;
  }
  throw StateError(
    'Invalid sync transition: '
    '${localSyncStateValue(current)} -> $event',
  );
}

SyncConflictClass syncConflictClassForEntity(String entityType) {
  const financial = {
    'sale',
    'sale_return',
    'payment',
    'refund',
    'customer_credit_entry',
    'customer_loyalty_entry',
    'promotion_redemption',
    'expense',
    'purchase_receipt',
    'supplier_ledger_entry',
  };
  const inventory = {'stock_movement', 'store_transfer'};
  const configuration = {
    'loyalty_program',
    'promotion',
    'tax_configuration',
    'employee_role',
    'store_access',
  };

  if (financial.contains(entityType)) {
    return SyncConflictClass.appendOnlyFinancial;
  }
  if (inventory.contains(entityType)) {
    return SyncConflictClass.inventoryMovement;
  }
  if (configuration.contains(entityType)) {
    return SyncConflictClass.configurationSecurity;
  }
  return SyncConflictClass.masterData;
}
