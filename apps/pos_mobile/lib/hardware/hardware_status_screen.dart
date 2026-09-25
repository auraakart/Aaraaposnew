import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import 'hardware_domain.dart';

class HardwareStatusScreen extends StatelessWidget {
  const HardwareStatusScreen({
    required this.saleContext,
    super.key,
  });

  final LocalSaleContext saleContext;

  @override
  Widget build(BuildContext context) {
    final statuses = defaultHardwareCapabilityStatuses();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.point_of_sale_outlined),
            title: Text(saleContext.storeName),
            subtitle: Text(
              'Terminal ${saleContext.terminalCode} • device capabilities are terminal-scoped',
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          child: ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Hardware stays behind adapters'),
            subtitle: Text(
              'Vendor SDKs never become business-domain dependencies. '
              'Configured devices must be validated on real hardware before production.',
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final status in statuses)
          Card(
            child: ListTile(
              leading: Icon(_icon(status.type)),
              title: Text(status.title),
              subtitle: Text(status.detail),
              trailing: Chip(label: Text(_readiness(status.readiness))),
            ),
          ),
      ],
    );
  }
}

String _readiness(HardwareReadiness readiness) => switch (readiness) {
      HardwareReadiness.appReady => 'App ready',
      HardwareReadiness.adapterReady => 'Adapter ready',
      HardwareReadiness.integrationRequired => 'Needs integration',
    };

IconData _icon(HardwareDeviceType type) => switch (type) {
      HardwareDeviceType.barcodeScanner => Icons.qr_code_scanner,
      HardwareDeviceType.receiptPrinter => Icons.print_outlined,
      HardwareDeviceType.cashDrawer => Icons.point_of_sale_outlined,
      HardwareDeviceType.weighingScale => Icons.scale_outlined,
      HardwareDeviceType.customerDisplay => Icons.monitor_outlined,
      HardwareDeviceType.paymentTerminal => Icons.credit_card_outlined,
    };
