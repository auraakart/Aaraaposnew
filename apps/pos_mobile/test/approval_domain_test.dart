import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('approval fingerprint is stable regardless of fact ordering', () {
    final first = buildApprovalFingerprint(
      actionType: 'refund',
      entityId: 'sale-1',
      facts: const ['line-b:1000', 'amount:600000', 'line-a:1000'],
    );
    final second = buildApprovalFingerprint(
      actionType: 'refund',
      entityId: 'sale-1',
      facts: const ['line-a:1000', 'line-b:1000', 'amount:600000'],
    );

    expect(first, second);
  });

  test('approval fingerprint rejects ambiguous separators', () {
    expect(
      () => buildApprovalFingerprint(
        actionType: 'refund',
        entityId: 'sale-1',
        facts: const ['line|1:1000'],
      ),
      throwsArgumentError,
    );
  });
}
