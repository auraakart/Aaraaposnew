import 'package:flutter/material.dart';

import '../accounting/accounting_export_screen.dart';
import '../audit/audit_history_screen.dart';
import '../commerce/commerce_orders_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../hardware/hardware_status_screen.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_accessibility_screen.dart';
import '../loyalty/loyalty_promotions_screen.dart';
import '../multistore/store_scope_screen.dart';
import '../operations/operations_screen.dart';
import '../purchases/purchases_screen.dart';
import '../returns/returns_screen.dart';
import '../sell/local_pos_database.dart';
import '../sync/integration_status_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.monitor_heart_outlined),
            title: const Text('Diagnostics'),
            subtitle: const Text(
              'Local database integrity, sync status and safe technical counts',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Diagnostics')),
                    body: DiagnosticsScreen(
                      database: database,
                      saleContext: saleContext,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history_outlined),
            title: const Text('Audit History'),
            subtitle: const Text(
              'Owner/Manager history for critical sales, stock and cash actions',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Audit History')),
                    body: AuditHistoryScreen(
                      database: database,
                      saleContext: saleContext,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.translate_outlined),
            title: Text(AppStrings.of(context).languageAccessibility),
            subtitle: const Text(
              'English, Hindi and Tamil shell support with device text scaling',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Text(
                        AppStrings.of(context).languageAccessibility,
                      ),
                    ),
                    body: LanguageAccessibilityScreen(database: database),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.devices_other_outlined),
            title: const Text('Hardware & Devices'),
            subtitle: const Text(
              'Scanner, printer, drawer, scale and terminal readiness',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Hardware & Devices')),
                    body: HardwareStatusScreen(saleContext: saleContext),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.shopping_bag_outlined),
            title: const Text('Commerce Orders'),
            subtitle: const Text(
              'Capture phone/WhatsApp orders and bill them through Sell',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Commerce Orders')),
                    body: CommerceOrdersScreen(
                      database: database,
                      saleContext: saleContext,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.table_view_outlined),
            title: const Text('Accounting Export'),
            subtitle: const Text(
              'Sales, tax, purchases, expenses and settlement registers',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Accounting Export')),
                    body: AccountingExportScreen(database: database),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('Integrations & Sync'),
            subtitle: const Text(
              'Sync queue, provider capabilities and integration boundaries',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Integrations & Sync')),
                    body: IntegrationStatusScreen(database: database),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.stars_outlined),
            title: const Text('Loyalty & Offers'),
            subtitle: const Text(
              'Customer points and simple promotional offers',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Loyalty & Offers')),
                    body: LoyaltyPromotionsScreen(
                      database: database,
                      saleContext: saleContext,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.store_mall_directory_outlined),
            title: const Text('Store & Terminal'),
            subtitle: const Text(
              'Store scope, offline binding and multi-store boundaries',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Store & Terminal')),
                    body: StoreScopeScreen(saleContext: saleContext),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.assignment_return_outlined),
            title: const Text('Returns & Refunds'),
            subtitle: const Text(
              'Find a bill, return items and record the refund',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Returns & Refunds')),
                    body: ReturnsScreen(
                      database: database,
                      saleContext: saleContext,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Store Operations'),
            subtitle: const Text(
              'Employees, shifts, drawer cash and expenses',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Store Operations')),
                    body: OperationsScreen(
                      database: database,
                      saleContext: saleContext,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: const Text('Purchases & Suppliers'),
            subtitle: const Text(
              'Create orders, receive stock, returns and supplier payments',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Purchases & Suppliers')),
                    body: PurchasesScreen(
                      database: database,
                      saleContext: saleContext,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
