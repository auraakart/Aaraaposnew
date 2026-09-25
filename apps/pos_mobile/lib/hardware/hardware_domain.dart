enum HardwareDeviceType {
  barcodeScanner,
  receiptPrinter,
  cashDrawer,
  weighingScale,
  customerDisplay,
  paymentTerminal,
}

enum HardwareReadiness {
  appReady,
  adapterReady,
  integrationRequired,
}

class HardwareCapabilityStatus {
  const HardwareCapabilityStatus({
    required this.type,
    required this.title,
    required this.readiness,
    required this.detail,
  });

  final HardwareDeviceType type;
  final String title;
  final HardwareReadiness readiness;
  final String detail;
}

class HardwareCommandContext {
  const HardwareCommandContext({
    required this.terminalId,
    this.sourceEntityType,
    this.sourceEntityId,
  });

  final String terminalId;
  final String? sourceEntityType;
  final String? sourceEntityId;

  void requireSource(Set<String> allowedTypes) {
    final type = sourceEntityType;
    final id = sourceEntityId;
    if (type == null || id == null || !allowedTypes.contains(type)) {
      throw StateError('This hardware action requires valid source evidence');
    }
  }
}

abstract interface class CashDrawerAdapter {
  bool get configured;

  Future<void> open(HardwareCommandContext context);
}

abstract interface class WeighingScaleAdapter {
  bool get configured;

  Future<int> readWeightMilli();
}

abstract interface class CustomerDisplayAdapter {
  bool get configured;

  Future<void> showTotalMinor(int totalMinor);
}

abstract interface class PaymentTerminalHardwareAdapter {
  bool get configured;

  Future<void> beginProviderFlow({
    required int amountMinor,
    required String paymentId,
  });
}

class UnconfiguredCashDrawerAdapter implements CashDrawerAdapter {
  const UnconfiguredCashDrawerAdapter();

  @override
  bool get configured => false;

  @override
  Future<void> open(HardwareCommandContext context) {
    throw StateError('No cash drawer is configured');
  }
}

class UnconfiguredWeighingScaleAdapter implements WeighingScaleAdapter {
  const UnconfiguredWeighingScaleAdapter();

  @override
  bool get configured => false;

  @override
  Future<int> readWeightMilli() {
    throw StateError('No weighing scale is configured');
  }
}

class UnconfiguredCustomerDisplayAdapter implements CustomerDisplayAdapter {
  const UnconfiguredCustomerDisplayAdapter();

  @override
  bool get configured => false;

  @override
  Future<void> showTotalMinor(int totalMinor) {
    throw StateError('No customer display is configured');
  }
}

class UnconfiguredPaymentTerminalAdapter
    implements PaymentTerminalHardwareAdapter {
  const UnconfiguredPaymentTerminalAdapter();

  @override
  bool get configured => false;

  @override
  Future<void> beginProviderFlow({
    required int amountMinor,
    required String paymentId,
  }) {
    throw StateError('No payment terminal is configured');
  }
}

List<HardwareCapabilityStatus> defaultHardwareCapabilityStatuses() => const [
      HardwareCapabilityStatus(
        type: HardwareDeviceType.barcodeScanner,
        title: 'Camera barcode scanner',
        readiness: HardwareReadiness.appReady,
        detail:
            'Camera scanning is integrated in Sell. Physical-device validation is still required.',
      ),
      HardwareCapabilityStatus(
        type: HardwareDeviceType.barcodeScanner,
        title: 'Keyboard / wedge scanner',
        readiness: HardwareReadiness.appReady,
        detail:
            'Barcode text can use the existing search input. Device certification is not claimed.',
      ),
      HardwareCapabilityStatus(
        type: HardwareDeviceType.receiptPrinter,
        title: 'Receipt printer',
        readiness: HardwareReadiness.adapterReady,
        detail:
            'Printer contract exists; Bluetooth/USB/network vendor integration is not configured.',
      ),
      HardwareCapabilityStatus(
        type: HardwareDeviceType.cashDrawer,
        title: 'Cash drawer',
        readiness: HardwareReadiness.integrationRequired,
        detail:
            'Command contract requires sale, cash movement or shift provenance before opening.',
      ),
      HardwareCapabilityStatus(
        type: HardwareDeviceType.weighingScale,
        title: 'Weighing scale',
        readiness: HardwareReadiness.integrationRequired,
        detail:
            'Weight adapter contract exists; no physical scale protocol is configured.',
      ),
      HardwareCapabilityStatus(
        type: HardwareDeviceType.customerDisplay,
        title: 'Customer display',
        readiness: HardwareReadiness.integrationRequired,
        detail:
            'Display adapter contract exists; no vendor display is configured.',
      ),
      HardwareCapabilityStatus(
        type: HardwareDeviceType.paymentTerminal,
        title: 'Payment terminal',
        readiness: HardwareReadiness.integrationRequired,
        detail:
            'Hardware flow remains behind payment-provider integration and cannot fabricate capture.',
      ),
    ];
