import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expected cash is deterministic', () {
    expect(
      expectedClosingCashMinor(
        openingCashMinor: 50000,
        cashSalesMinor: 100000,
        cashCreditCollectionsMinor: 20000,
        cashDepositsMinor: 5000,
        cashWithdrawalsMinor: 10000,
        cashExpensesMinor: 15000,
      ),
      150000,
    );
  });

  test('negative expected cash is rejected', () {
    expect(
      () => expectedClosingCashMinor(
        openingCashMinor: 0,
        cashSalesMinor: 0,
        cashCreditCollectionsMinor: 0,
        cashDepositsMinor: 0,
        cashWithdrawalsMinor: 1000,
        cashExpensesMinor: 0,
      ),
      throwsStateError,
    );
  });
}
