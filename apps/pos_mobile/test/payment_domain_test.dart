import 'package:aaraapos_pos/payments/payment_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('split allocations must equal sale total', () {
    expect(
      () => validatePaymentAllocations(
        10000,
        const [
          PaymentAllocation(
            id: 'cash-1',
            method: PaymentMethod.cash,
            amountMinor: 4000,
            status: PaymentStatus.captured,
          ),
          PaymentAllocation(
            id: 'upi-1',
            method: PaymentMethod.upi,
            amountMinor: 6000,
            status: PaymentStatus.captured,
            provider: 'provider',
            providerReference: 'ref-1',
          ),
        ],
      ),
      returnsNormally,
    );

    expect(
      () => validatePaymentAllocations(
        10000,
        const [
          PaymentAllocation(
            id: 'cash-1',
            method: PaymentMethod.cash,
            amountMinor: 4000,
            status: PaymentStatus.captured,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('pending external payment prevents sale finalization', () {
    expect(
      canFinalizeSale(
        10000,
        const [
          PaymentAllocation(
            id: 'cash-1',
            method: PaymentMethod.cash,
            amountMinor: 5000,
            status: PaymentStatus.captured,
          ),
          PaymentAllocation(
            id: 'upi-1',
            method: PaymentMethod.upi,
            amountMinor: 5000,
            status: PaymentStatus.pending,
            provider: 'provider',
          ),
        ],
      ),
      isFalse,
    );
  });

  test('unconfigured external adapter is explicitly unavailable', () async {
    const adapter = UnconfiguredPaymentAdapter(
      PaymentMethod.upi,
      'not-configured',
    );

    expect(await adapter.isAvailable(), isFalse);
    expect(
      () => adapter.initiate(
        const PaymentProviderRequest(
          paymentId: 'p1',
          amountMinor: 5000,
          idempotencyKey: 'i1',
          storeId: 's1',
          terminalId: 't1',
        ),
      ),
      throwsStateError,
    );
  });

  test('reconciliation requires amount and status agreement', () {
    expect(
      reconcilePayment(
        expectedMinor: 5000,
        providerReportedMinor: 5000,
        localStatus: PaymentStatus.captured,
        providerStatus: PaymentStatus.captured,
      ),
      ReconciliationStatus.matched,
    );
    expect(
      reconcilePayment(
        expectedMinor: 5000,
        providerReportedMinor: 4900,
        localStatus: PaymentStatus.captured,
        providerStatus: PaymentStatus.captured,
      ),
      ReconciliationStatus.mismatch,
    );
  });
}
