class LocalAuditEvent {
  const LocalAuditEvent({
    required this.id,
    required this.actorUserId,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.occurredAt,
    required this.outcome,
    required this.metadata,
  });

  final String id;
  final String actorUserId;
  final String action;
  final String entityType;
  final String entityId;
  final DateTime occurredAt;
  final String outcome;
  final Map<String, Object?> metadata;
}

String auditActionLabel(String action) => switch (action) {
      'sale.finalized' => 'Sale finalized',
      'sale.returned' => 'Sale returned',
      'stock.movement' => 'Stock changed',
      'shift.opened' => 'Shift opened',
      'shift.closed' => 'Shift closed',
      'cash.movement' => 'Drawer cash changed',
      'expense.recorded' => 'Expense recorded',
      'employee.created' => 'Employee added',
      'supplier.paid' => 'Supplier paid',
      _ => action,
    };

String auditEntityLabel(LocalAuditEvent event) {
  final reference =
      event.metadata['reference']?.toString().trim();
  if (reference != null && reference.isNotEmpty) {
    return '${event.entityType} • $reference';
  }
  return '${event.entityType} • ${event.entityId}';
}
