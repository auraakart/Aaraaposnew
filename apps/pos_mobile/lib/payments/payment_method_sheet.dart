import 'package:flutter/material.dart';

import 'payment_domain.dart';

enum PaymentChoice { cash, upi, card, customerCredit, split }

Future<PaymentChoice?> showPaymentMethodSheet(
  BuildContext context, {
  required Set<PaymentMethod> availableMethods,
  required bool splitEnabled,
}) {
  return showModalBottomSheet<PaymentChoice>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              'How did the customer pay?',
              style: Theme.of(sheetContext).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            _PaymentTile(
              icon: Icons.payments_outlined,
              title: 'Cash',
              enabled: availableMethods.contains(PaymentMethod.cash),
              onTap: () => Navigator.pop(sheetContext, PaymentChoice.cash),
            ),
            _PaymentTile(
              icon: Icons.qr_code_2,
              title: 'UPI',
              enabled: availableMethods.contains(PaymentMethod.upi),
              disabledReason: 'Connect a payment provider to enable UPI.',
              onTap: () => Navigator.pop(sheetContext, PaymentChoice.upi),
            ),
            _PaymentTile(
              icon: Icons.credit_card,
              title: 'Card',
              enabled: availableMethods.contains(PaymentMethod.card),
              disabledReason: 'Connect a payment provider to enable cards.',
              onTap: () => Navigator.pop(sheetContext, PaymentChoice.card),
            ),
            _PaymentTile(
              icon: Icons.schedule_send_outlined,
              title: 'Customer Credit / Pay Later',
              enabled: availableMethods.contains(PaymentMethod.customerCredit),
              disabledReason: 'Select a customer before using Pay Later.',
              onTap: () =>
                  Navigator.pop(sheetContext, PaymentChoice.customerCredit),
            ),
            _PaymentTile(
              icon: Icons.call_split,
              title: 'Split payment',
              enabled: splitEnabled,
              disabledReason:
                  'Available when at least two payment methods are configured.',
              onTap: () => Navigator.pop(sheetContext, PaymentChoice.split),
            ),
          ],
        ),
      );
    },
  );
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.onTap,
    this.disabledReason,
  });

  final IconData icon;
  final String title;
  final bool enabled;
  final VoidCallback onTap;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: enabled,
      button: true,
      label: enabled ? title : '$title unavailable',
      child: ListTile(
        minTileHeight: 64,
        enabled: enabled,
        leading: Icon(icon),
        title: Text(title),
        subtitle:
            enabled || disabledReason == null ? null : Text(disabledReason!),
        trailing: enabled ? const Icon(Icons.chevron_right) : const Icon(Icons.lock_outline),
        onTap: enabled ? onTap : null,
      ),
    );
  }
}
