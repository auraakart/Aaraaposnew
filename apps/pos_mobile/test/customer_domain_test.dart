import 'package:aaraapos_pos/customers/customer_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('partial collection preserves remaining overdue credit', () {
    final summary = summarizeCredit(
      [
        CreditEntry(
          id: 'charge-1',
          customerId: 'customer-1',
          type: CreditEntryType.charge,
          amountMinor: 85000,
          occurredAt: DateTime.utc(2026, 9, 1),
          dueDate: DateTime.utc(2026, 9, 10),
          saleId: 'sale-1',
        ),
        CreditEntry(
          id: 'payment-1',
          customerId: 'customer-1',
          type: CreditEntryType.payment,
          amountMinor: 30000,
          occurredAt: DateTime.utc(2026, 9, 15),
        ),
      ],
      asOf: DateTime.utc(2026, 9, 25),
    );

    expect(summary.balanceMinor, 55000);
    expect(summary.overdueMinor, 55000);
    expect(summary.oldestOutstandingAt, DateTime.utc(2026, 9, 1));
  });

  test('over-collection is rejected', () {
    expect(
      () => summarizeCredit(
        [
          CreditEntry(
            id: 'charge-1',
            customerId: 'customer-1',
            type: CreditEntryType.charge,
            amountMinor: 50000,
            occurredAt: DateTime.utc(2026, 9, 1),
            saleId: 'sale-1',
          ),
          CreditEntry(
            id: 'payment-1',
            customerId: 'customer-1',
            type: CreditEntryType.payment,
            amountMinor: 60000,
            occurredAt: DateTime.utc(2026, 9, 2),
          ),
        ],
        asOf: DateTime.utc(2026, 9, 25),
      ),
      throwsStateError,
    );
  });
}
