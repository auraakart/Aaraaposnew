enum PaymentMethod { cash, upi, card }

enum PaymentStatus { pending, authorized, captured, failed, cancelled }

enum ReconciliationStatus { notApplicable, pending, matched, mismatch }

class PaymentAllocation {
  const PaymentAllocation({
    required this.id,
    required this.method,
    required this.amountMinor,
    required this.status,
    this.provider,
    this.providerReference,
  });

  final String id;
  final PaymentMethod method;
  final int amountMinor;
  final PaymentStatus status;
  final String? provider;
  final String? providerReference;
}

class PaymentProviderRequest {
  const PaymentProviderRequest({
    required this.paymentId,
    required this.amountMinor,
    required this.idempotencyKey,
    required this.storeId,
    required this.terminalId,
  });

  final String paymentId;
  final int amountMinor;
  final String idempotencyKey;
  final String storeId;
  final String terminalId;
}

class PaymentProviderResult {
  const PaymentProviderResult({
    required this.status,
    required this.provider,
    this.providerReference,
    this.message,
  });

  final PaymentStatus status;
  final String provider;
  final String? providerReference;
  final String? message;
}

abstract interface class ExternalPaymentAdapter {
  PaymentMethod get method;
  String get provider;

  Future<bool> isAvailable();

  Future<PaymentProviderResult> initiate(PaymentProviderRequest request);

  Future<PaymentProviderResult> query(String providerReference);
}

class UnconfiguredPaymentAdapter implements ExternalPaymentAdapter {
  const UnconfiguredPaymentAdapter(this.method, this.provider);

  @override
  final PaymentMethod method;

  @override
  final String provider;

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<PaymentProviderResult> initiate(PaymentProviderRequest request) {
    throw StateError('$provider is not configured');
  }

  @override
  Future<PaymentProviderResult> query(String providerReference) {
    throw StateError('$provider is not configured');
  }
}

void validatePaymentAllocations(
  int saleTotalMinor,
  List<PaymentAllocation> allocations,
) {
  if (saleTotalMinor <= 0 || allocations.isEmpty) {
    throw ArgumentError('A positive sale total and payment are required');
  }

  var allocatedMinor = 0;
  for (final allocation in allocations) {
    if (allocation.amountMinor <= 0) {
      throw ArgumentError('Payment amount must be positive');
    }
    if (allocation.method != PaymentMethod.cash &&
        allocation.status == PaymentStatus.captured &&
        (allocation.provider == null || allocation.providerReference == null)) {
      throw ArgumentError('Captured external payment requires provider evidence');
    }
    allocatedMinor += allocation.amountMinor;
  }

  if (allocatedMinor != saleTotalMinor) {
    throw ArgumentError('Payment allocations must equal the sale total');
  }
}

bool canFinalizeSale(
  int saleTotalMinor,
  List<PaymentAllocation> allocations,
) {
  try {
    validatePaymentAllocations(saleTotalMinor, allocations);
  } on ArgumentError {
    return false;
  }
  return allocations.every(
    (allocation) => allocation.status == PaymentStatus.captured,
  );
}

ReconciliationStatus reconcilePayment({
  required int expectedMinor,
  required int providerReportedMinor,
  required PaymentStatus localStatus,
  required PaymentStatus providerStatus,
}) {
  if (expectedMinor <= 0 || providerReportedMinor <= 0) {
    throw ArgumentError('Reconciliation amounts must be positive');
  }

  if (expectedMinor == providerReportedMinor &&
      localStatus == PaymentStatus.captured &&
      providerStatus == PaymentStatus.captured) {
    return ReconciliationStatus.matched;
  }
  return ReconciliationStatus.mismatch;
}

String paymentMethodLabel(PaymentMethod method) {
  return switch (method) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.upi => 'UPI',
    PaymentMethod.card => 'Card',
  };
}


class PaymentCoordinator {
  PaymentCoordinator(Iterable<ExternalPaymentAdapter> adapters)
      : _adapters = {
          for (final adapter in adapters) adapter.method: adapter,
        };

  final Map<PaymentMethod, ExternalPaymentAdapter> _adapters;

  Future<Set<PaymentMethod>> availableMethods() async {
    final available = <PaymentMethod>{PaymentMethod.cash};
    for (final entry in _adapters.entries) {
      if (await entry.value.isAvailable()) {
        available.add(entry.key);
      }
    }
    return available;
  }

  Future<PaymentAllocation> initiateExternal({
    required PaymentMethod method,
    required PaymentProviderRequest request,
  }) async {
    if (method == PaymentMethod.cash) {
      throw ArgumentError('Cash does not use an external provider adapter');
    }

    final adapter = _adapters[method];
    if (adapter == null || !await adapter.isAvailable()) {
      throw StateError('${paymentMethodLabel(method)} provider is not available');
    }

    final result = await adapter.initiate(request);
    return PaymentAllocation(
      id: request.paymentId,
      method: method,
      amountMinor: request.amountMinor,
      status: result.status,
      provider: result.provider,
      providerReference: result.providerReference,
    );
  }
}
