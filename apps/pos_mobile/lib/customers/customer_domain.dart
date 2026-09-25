enum CommunicationConsent { unknown, optedIn, optedOut }

enum CreditEntryType {
  charge,
  payment,
  correctionIncrease,
  correctionDecrease,
}

class CreditEntry {
  const CreditEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amountMinor,
    required this.occurredAt,
    this.dueDate,
    this.saleId,
  });

  final String id;
  final String customerId;
  final CreditEntryType type;
  final int amountMinor;
  final DateTime occurredAt;
  final DateTime? dueDate;
  final String? saleId;
}

class CreditSummary {
  const CreditSummary({
    required this.balanceMinor,
    required this.overdueMinor,
    this.oldestOutstandingAt,
  });

  final int balanceMinor;
  final int overdueMinor;
  final DateTime? oldestOutstandingAt;
}

class LocalCustomer {
  const LocalCustomer({
    required this.id,
    required this.name,
    required this.creditBalanceMinor,
    required this.overdueMinor,
    required this.consent,
    this.mobile,
    this.lastPurchaseAt,
  });

  final String id;
  final String name;
  final String? mobile;
  final int creditBalanceMinor;
  final int overdueMinor;
  final DateTime? lastPurchaseAt;
  final CommunicationConsent consent;
}

bool _increasesCredit(CreditEntryType type) {
  return type == CreditEntryType.charge ||
      type == CreditEntryType.correctionIncrease;
}

void validateCreditEntry(CreditEntry entry) {
  if (entry.amountMinor <= 0) {
    throw ArgumentError('Credit amount must be positive');
  }
  if (entry.type == CreditEntryType.charge && entry.saleId == null) {
    throw ArgumentError('Credit sale must link to a sale');
  }
}

CreditSummary summarizeCredit(
  List<CreditEntry> entries, {
  required DateTime asOf,
}) {
  final ordered = [...entries]
    ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));

  final open = <({int remainingMinor, DateTime occurredAt, DateTime? dueDate})>[];

  for (final entry in ordered) {
    validateCreditEntry(entry);
    if (_increasesCredit(entry.type)) {
      open.add((
        remainingMinor: entry.amountMinor,
        occurredAt: entry.occurredAt,
        dueDate: entry.dueDate,
      ));
      continue;
    }

    var remainingPayment = entry.amountMinor;
    for (var index = 0; index < open.length && remainingPayment > 0; index++) {
      final current = open[index];
      final applied = current.remainingMinor < remainingPayment
          ? current.remainingMinor
          : remainingPayment;
      open[index] = (
        remainingMinor: current.remainingMinor - applied,
        occurredAt: current.occurredAt,
        dueDate: current.dueDate,
      );
      remainingPayment -= applied;
    }
    if (remainingPayment > 0) {
      throw StateError('Customer credit cannot be over-collected');
    }
  }

  final outstanding = open.where((item) => item.remainingMinor > 0).toList();
  final balance = outstanding.fold<int>(
    0,
    (sum, item) => sum + item.remainingMinor,
  );
  final asOfDay = DateTime.utc(asOf.year, asOf.month, asOf.day);
  final overdue = outstanding
      .where(
        (item) =>
            item.dueDate != null &&
            DateTime.utc(
              item.dueDate!.year,
              item.dueDate!.month,
              item.dueDate!.day,
            ).isBefore(asOfDay),
      )
      .fold<int>(0, (sum, item) => sum + item.remainingMinor);

  return CreditSummary(
    balanceMinor: balance,
    overdueMinor: overdue,
    oldestOutstandingAt:
        outstanding.isEmpty ? null : outstanding.first.occurredAt,
  );
}

String communicationConsentValue(CommunicationConsent consent) {
  return switch (consent) {
    CommunicationConsent.unknown => 'unknown',
    CommunicationConsent.optedIn => 'opted_in',
    CommunicationConsent.optedOut => 'opted_out',
  };
}

CommunicationConsent communicationConsentFromValue(String value) {
  return switch (value) {
    'opted_in' => CommunicationConsent.optedIn,
    'opted_out' => CommunicationConsent.optedOut,
    _ => CommunicationConsent.unknown,
  };
}
