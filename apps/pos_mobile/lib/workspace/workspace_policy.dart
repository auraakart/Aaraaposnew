import '../operations/operations_domain.dart';

enum WorkspaceDestination {
  home,
  sell,
  stock,
  customers,
  more,
}

enum MoreFeature {
  employeeAccess,
  recoveryReadiness,
  diagnostics,
  auditHistory,
  languageAccessibility,
  hardwareDevices,
  commerceOrders,
  accountingExport,
  integrationsSync,
  loyaltyOffers,
  storeTerminal,
  returnsRefunds,
  storeOperations,
  purchasesSuppliers,
}

List<WorkspaceDestination> workspaceDestinationsForRole(
  EmployeeRole role,
) =>
    switch (role) {
      EmployeeRole.owner || EmployeeRole.manager => const [
          WorkspaceDestination.home,
          WorkspaceDestination.sell,
          WorkspaceDestination.stock,
          WorkspaceDestination.customers,
          WorkspaceDestination.more,
        ],
      EmployeeRole.cashier => const [
          WorkspaceDestination.sell,
          WorkspaceDestination.customers,
          WorkspaceDestination.more,
        ],
      EmployeeRole.stockWorker => const [
          WorkspaceDestination.stock,
          WorkspaceDestination.more,
        ],
    };

Set<MoreFeature> moreFeaturesForRole(EmployeeRole role) => switch (role) {
      EmployeeRole.owner || EmployeeRole.manager => MoreFeature.values.toSet(),
      EmployeeRole.cashier => const {
          MoreFeature.languageAccessibility,
          MoreFeature.hardwareDevices,
          MoreFeature.commerceOrders,
          MoreFeature.returnsRefunds,
          MoreFeature.storeOperations,
        },
      EmployeeRole.stockWorker => const {
          MoreFeature.languageAccessibility,
          MoreFeature.hardwareDevices,
          MoreFeature.storeTerminal,
        },
    };

WorkspaceDestination defaultWorkspaceDestination(EmployeeRole role) =>
    workspaceDestinationsForRole(role).first;
