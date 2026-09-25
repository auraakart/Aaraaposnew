import 'package:aaraapos_pos/hardware/hardware_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default readiness distinguishes app-ready from integration-required', () {
    final statuses = defaultHardwareCapabilityStatuses();

    expect(
      statuses.any(
        (item) =>
            item.type == HardwareDeviceType.barcodeScanner &&
            item.readiness == HardwareReadiness.appReady,
      ),
      isTrue,
    );
    expect(
      statuses.any(
        (item) =>
            item.type == HardwareDeviceType.cashDrawer &&
            item.readiness == HardwareReadiness.integrationRequired,
      ),
      isTrue,
    );
  });

  test('cash drawer provenance accepts only controlled financial sources', () {
    const sale = HardwareCommandContext(
      terminalId: 'terminal-1',
      sourceEntityType: 'sale',
      sourceEntityId: 'sale-1',
    );
    expect(
      () => sale.requireSource({'sale', 'cash_movement', 'shift'}),
      returnsNormally,
    );

    const arbitrary = HardwareCommandContext(
      terminalId: 'terminal-1',
      sourceEntityType: 'customer',
      sourceEntityId: 'customer-1',
    );
    expect(
      () => arbitrary.requireSource({'sale', 'cash_movement', 'shift'}),
      throwsStateError,
    );
  });

  test('unconfigured adapters fail rather than pretending success', () async {
    const drawer = UnconfiguredCashDrawerAdapter();
    const scale = UnconfiguredWeighingScaleAdapter();
    const display = UnconfiguredCustomerDisplayAdapter();
    const terminal = UnconfiguredPaymentTerminalAdapter();

    expect(drawer.configured, isFalse);
    await expectLater(
      drawer.open(
        const HardwareCommandContext(
          terminalId: 'terminal-1',
          sourceEntityType: 'sale',
          sourceEntityId: 'sale-1',
        ),
      ),
      throwsStateError,
    );
    await expectLater(scale.readWeightMilli(), throwsStateError);
    await expectLater(display.showTotalMinor(10000), throwsStateError);
    await expectLater(
      terminal.beginProviderFlow(amountMinor: 10000, paymentId: 'payment-1'),
      throwsStateError,
    );
  });
}
