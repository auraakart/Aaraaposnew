import 'package:flutter/material.dart';

import '../accounting/accounting_export_screen.dart';
import '../auth/local_access_screen.dart';
import '../audit/audit_history_screen.dart';
import '../commerce/commerce_orders_screen.dart';
import '../diagnostics/diagnostics_screen.dart';
import '../hardware/hardware_status_screen.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_accessibility_screen.dart';
import '../loyalty/loyalty_promotions_screen.dart';
import '../multistore/store_scope_screen.dart';
import '../operations/operations_domain.dart';
import '../operations/operations_screen.dart';
import '../purchases/purchases_screen.dart';
import '../recovery/recovery_readiness_screen.dart';
import '../returns/returns_screen.dart';
import '../sell/local_pos_database.dart';
import '../sync/integration_status_screen.dart';
import '../workspace/workspace_policy.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({
    required this.database,
    required this.saleContext,
    required this.role,
    this.onSessionInvalidated,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;
  final EmployeeRole role;
  final VoidCallback? onSessionInvalidated;

  @override
  Widget build(BuildContext context) {
    final allowed = moreFeaturesForRole(role);
    final strings = AppStrings.of(context);

    final entries = <_MoreEntry>[
      _MoreEntry(
        feature: MoreFeature.employeeAccess,
        icon: Icons.manage_accounts_outlined,
        title: 'Employee Access',
        subtitle: 'Set or reset local device PINs for employees',
        bodyBuilder: (_) => LocalAccessScreen(
          database: database,
          saleContext: saleContext,
          onCurrentCredentialReset: onSessionInvalidated,
        ),
      ),
      _MoreEntry(
        feature: MoreFeature.recoveryReadiness,
        icon: Icons.restore_outlined,
        title: 'Recovery Readiness',
        subtitle:
            'Check local integrity and restore blockers without changing data',
        bodyBuilder: (_) => RecoveryReadinessScreen(
          database: database,
          saleContext: saleContext,
        ),
      ),
      _MoreEntry(
        feature: MoreFeature.diagnostics,
        icon: Icons.monitor_heart_outlined,
        title: 'Diagnostics',
        subtitle:
            'Local database integrity, sync status and safe technical counts',
        bodyBuilder: (_) => DiagnosticsScreen(
          database: database,
          saleContext: saleContext,
        ),
      ),
      _MoreEntry(
        feature: MoreFeature.auditHistory,
        icon: Icons.history_outlined,
        title: 'Audit History',
        subtitle:
            'Owner/Manager history for critical sales, stock and cash actions',
        bodyBuilder: (_) => AuditHistoryScreen(
          database: database,
          saleContext: saleContext,
        ),
      ),
      _MoreEntry(
        feature: MoreFeature.languageAccessibility,
        icon: Icons.translate_outlined,
        title: strings.languageAccessibility,
        subtitle:
            'English, Hindi and Tamil shell support with device text scaling',
        bodyBuilder: (_) => LanguageAccessibilityScreen(database: database),
      ),
      _MoreEntry(
        feature: MoreFeature.hardwareDevices,
        icon: Icons.devices_other_outlined,
        title: 'Hardware & Devices',
        subtitle: 'Scanner, printer, drawer, scale and terminal readiness',
        bodyBuilder: (_) => HardwareStatusScreen(saleContext: saleContext),
      ),
      _MoreEntry(
        feature: MoreFeature.commerceOrders,
        icon: Icons.shopping_bag_outlined,
        title: 'Commerce Orders',
        subtitle: 'Capture phone/WhatsApp orders and bill them through Sell',
        bodyBuilder: (_) => CommerceOrdersScreen(
          database: database,
          saleContext: saleContext,
        ),
      ),
      _MoreEntry(
        feature: MoreFeature.accountingExport,
        icon: Icons.table_view_outlined,
        title: 'Accounting Export',
        subtitle:
            'Sales, tax, purchases, expenses and settlement registers',
        bodyBuilder: (_) => AccountingExportScreen(database: database),
      ),
      _MoreEntry(
        feature: MoreFeature.integrationsSync,
        icon: Icons.hub_outlined,
        title: 'Integrations & Sync',
        subtitle:
            'Sync queue, provider capabilities and integration boundaries',
        bodyBuilder: (_) => IntegrationStatusScreen(database: database),
      ),
      _MoreEntry(
        feature: MoreFeature.loyaltyOffers,
        icon: Icons.stars_outlined,
        title: 'Loyalty & Offers',
        subtitle: 'Customer points and simple promotional offers',
        bodyBuilder: (_) => LoyaltyPromotionsScreen(
          database: database,
          saleContext: saleContext,
        ),
      ),
      _MoreEntry(
        feature: MoreFeature.storeTerminal,
        icon: Icons.store_mall_directory_outlined,
        title: 'Store & Terminal',
        subtitle: 'Store scope, offline binding and multi-store boundaries',
        bodyBuilder: (_) => StoreScopeScreen(saleContext: saleContext),
      ),
      _MoreEntry(
        feature: MoreFeature.returnsRefunds,
        icon: Icons.assignment_return_outlined,
        title: 'Returns & Refunds',
        subtitle: 'Find a bill, return items and record the refund',
        bodyBuilder: (_) => ReturnsScreen(
          database: database,
          saleContext: saleContext,
        ),
      ),
      _MoreEntry(
        feature: MoreFeature.storeOperations,
        icon: Icons.storefront_outlined,
        title: 'Store Operations',
        subtitle: 'Employees, shifts, drawer cash and expenses',
        bodyBuilder: (_) => OperationsScreen(
          database: database,
          saleContext: saleContext,
        ),
      ),
      _MoreEntry(
        feature: MoreFeature.purchasesSuppliers,
        icon: Icons.local_shipping_outlined,
        title: 'Purchases & Suppliers',
        subtitle:
            'Create orders, receive stock, returns and supplier payments',
        bodyBuilder: (_) => PurchasesScreen(
          database: database,
          saleContext: saleContext,
        ),
      ),
    ];

    final visibleEntries =
        entries.where((entry) => allowed.contains(entry.feature)).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final entry in visibleEntries)
          Card(
            child: ListTile(
              leading: Icon(entry.icon),
              title: Text(entry.title),
              subtitle: Text(entry.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (routeContext) => Scaffold(
                      appBar: AppBar(title: Text(entry.title)),
                      body: entry.bodyBuilder(routeContext),
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

class _MoreEntry {
  const _MoreEntry({
    required this.feature,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bodyBuilder,
  });

  final MoreFeature feature;
  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder bodyBuilder;
}
