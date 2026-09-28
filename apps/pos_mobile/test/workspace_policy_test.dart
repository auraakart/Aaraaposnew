import 'package:aaraapos_pos/operations/operations_domain.dart';
import 'package:aaraapos_pos/workspace/workspace_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Owner and Manager retain the full primary workspace', () {
    for (final role in [EmployeeRole.owner, EmployeeRole.manager]) {
      expect(
        workspaceDestinationsForRole(role),
        const [
          WorkspaceDestination.home,
          WorkspaceDestination.sell,
          WorkspaceDestination.stock,
          WorkspaceDestination.customers,
          WorkspaceDestination.more,
        ],
      );
      expect(
        moreFeaturesForRole(role),
        MoreFeature.values.toSet(),
      );
    }
  });

  test('Cashier defaults to Sell and does not see admin/accounting surfaces', () {
    final destinations =
        workspaceDestinationsForRole(EmployeeRole.cashier);
    final more = moreFeaturesForRole(EmployeeRole.cashier);

    expect(destinations.first, WorkspaceDestination.sell);
    expect(destinations, contains(WorkspaceDestination.customers));
    expect(destinations, isNot(contains(WorkspaceDestination.stock)));
    expect(destinations, isNot(contains(WorkspaceDestination.home)));

    expect(more, contains(MoreFeature.returnsRefunds));
    expect(more, contains(MoreFeature.storeOperations));
    expect(more, isNot(contains(MoreFeature.auditHistory)));
    expect(more, isNot(contains(MoreFeature.accountingExport)));
    expect(more, isNot(contains(MoreFeature.employeeAccess)));
  });

  test('Stock Worker sees only Stock and operationally safe More items', () {
    expect(
      workspaceDestinationsForRole(EmployeeRole.stockWorker),
      const [
        WorkspaceDestination.stock,
        WorkspaceDestination.more,
      ],
    );

    expect(
      moreFeaturesForRole(EmployeeRole.stockWorker),
      const {
        MoreFeature.languageAccessibility,
        MoreFeature.hardwareDevices,
        MoreFeature.storeTerminal,
      },
    );
  });
}
