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
