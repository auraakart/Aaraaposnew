enum EmployeeRole { owner, manager, cashier, stockWorker }

class LocalEmployee {
  const LocalEmployee({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    this.mobile,
  });

  final String id;
  final String name;
  final String? mobile;
  final EmployeeRole role;
  final bool active;
}

class LocalShift {
  const LocalShift({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.openedAt,
    required this.openingCashMinor,
    required this.status,
    this.closedAt,
    this.expectedClosingCashMinor,
    this.actualClosingCashMinor,
    this.varianceMinor,
  });

  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime openedAt;
  final int openingCashMinor;
  final String status;
  final DateTime? closedAt;
  final int? expectedClosingCashMinor;
  final int? actualClosingCashMinor;
  final int? varianceMinor;
}

class LocalExpense {
  const LocalExpense({
    required this.id,
    required this.category,
    required this.amountMinor,
    required this.paymentMethod,
    required this.occurredAt,
    this.note,
  });

  final String id;
  final String category;
  final int amountMinor;
  final String paymentMethod;
  final DateTime occurredAt;
  final String? note;
}

enum LocalApprovalStatus { pending, approved, rejected }

class LocalApprovalRequest {
  const LocalApprovalRequest({
    required this.id,
    required this.actionType,
    required this.entityType,
    required this.entityId,
    required this.requestedByEmployeeId,
    required this.requestedByName,
    required this.requestedAt,
    required this.status,
    required this.consumed,
    this.actionFingerprint,
    this.requestedAmountMinor,
    this.expiresAt,
    this.resolvedByEmployeeId,
    this.resolvedByName,
    this.resolvedAt,
    this.reason,
    this.consumedAt,
  });

  final String id;
  final String actionType;
  final String entityType;
  final String entityId;
  final String requestedByEmployeeId;
  final String requestedByName;
  final DateTime requestedAt;
  final LocalApprovalStatus status;
  final String? actionFingerprint;
  final int? requestedAmountMinor;
  final DateTime? expiresAt;
  final String? resolvedByEmployeeId;
  final String? resolvedByName;
  final DateTime? resolvedAt;
  final String? reason;
  final bool consumed;
  final DateTime? consumedAt;

  bool get isExpired =>
      expiresAt != null && !DateTime.now().toUtc().isBefore(expiresAt!.toUtc());
}

LocalApprovalStatus localApprovalStatusFromValue(String value) => switch (value) {
      'approved' => LocalApprovalStatus.approved,
      'rejected' => LocalApprovalStatus.rejected,
      _ => LocalApprovalStatus.pending,
    };

String localApprovalStatusValue(LocalApprovalStatus value) => switch (value) {
      LocalApprovalStatus.pending => 'pending',
      LocalApprovalStatus.approved => 'approved',
      LocalApprovalStatus.rejected => 'rejected',
    };

String buildApprovalFingerprint({
  required String actionType,
  required String entityId,
  required Iterable<String> facts,
}) {
  final normalizedAction = actionType.trim();
  final normalizedEntity = entityId.trim();
  if (normalizedAction.isEmpty ||
      normalizedEntity.isEmpty ||
      normalizedAction.contains('|') ||
      normalizedEntity.contains('|')) {
    throw ArgumentError('Invalid approval fingerprint identity');
  }

  final normalizedFacts = facts.map((fact) => fact.trim()).toList()..sort();
  if (normalizedFacts.any((fact) => fact.isEmpty || fact.contains('|'))) {
    throw ArgumentError('Invalid approval fingerprint facts');
  }

  return <String>[
    normalizedAction,
    normalizedEntity,
    ...normalizedFacts,
  ].join('|');
}

int expectedClosingCashMinor({
  required int openingCashMinor,
  required int cashSalesMinor,
  required int cashCreditCollectionsMinor,
  required int cashDepositsMinor,
  required int cashWithdrawalsMinor,
  required int cashExpensesMinor,
}) {
  final values = [
    openingCashMinor,
    cashSalesMinor,
    cashCreditCollectionsMinor,
    cashDepositsMinor,
    cashWithdrawalsMinor,
    cashExpensesMinor,
  ];
  if (values.any((value) => value < 0)) {
    throw ArgumentError('Cash values cannot be negative');
  }

  final expected = openingCashMinor +
      cashSalesMinor +
      cashCreditCollectionsMinor +
      cashDepositsMinor -
      cashWithdrawalsMinor -
      cashExpensesMinor;
  if (expected < 0) {
    throw StateError('Expected closing cash cannot be negative');
  }
  return expected;
}

String employeeRoleValue(EmployeeRole role) => switch (role) {
      EmployeeRole.owner => 'owner',
      EmployeeRole.manager => 'manager',
      EmployeeRole.cashier => 'cashier',
      EmployeeRole.stockWorker => 'stock_worker',
    };

EmployeeRole employeeRoleFromValue(String value) => switch (value) {
      'manager' => EmployeeRole.manager,
      'cashier' => EmployeeRole.cashier,
      'stock_worker' => EmployeeRole.stockWorker,
      _ => EmployeeRole.owner,
    };
