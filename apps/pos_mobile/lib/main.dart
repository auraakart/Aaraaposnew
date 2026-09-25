import 'package:flutter/material.dart';

void main() {
  runApp(const AaraaPosApp());
}

abstract final class AaraaSpacing {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
}

enum SyncState { pending, sending, acknowledged, conflict, rejected }

enum ConflictPolicy {
  appendOnlyFinancial,
  inventoryMovement,
  fieldAwareMasterData,
  serverAuthoritativeConfiguration,
}

class SyncEnvelope {
  const SyncEnvelope({
    required this.id,
    required this.organizationId,
    required this.businessId,
    required this.storeId,
    required this.terminalId,
    required this.idempotencyKey,
    required this.createdAt,
    required this.state,
    required this.conflictPolicy,
    required this.schemaVersion,
  });

  final String id;
  final String organizationId;
  final String businessId;
  final String storeId;
  final String terminalId;
  final String idempotencyKey;
  final DateTime createdAt;
  final SyncState state;
  final ConflictPolicy conflictPolicy;
  final int schemaVersion;

  bool get permitsLastWriteWins =>
      conflictPolicy == ConflictPolicy.fieldAwareMasterData;
}

class AaraaPosApp extends StatelessWidget {
  const AaraaPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006B5F),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'AaraaPOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        filledButtonTheme: const FilledButtonThemeData(
          style: ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(48, 52)),
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          height: 72,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        ),
      ),
      home: const FoundationHome(),
    );
  }
}

class FoundationHome extends StatefulWidget {
  const FoundationHome({super.key});

  @override
  State<FoundationHome> createState() => _FoundationHomeState();
}

class _FoundationHomeState extends State<FoundationHome> {
  int index = 0;

  static const destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.point_of_sale_outlined),
      selectedIcon: Icon(Icons.point_of_sale),
      label: 'Sell',
    ),
    NavigationDestination(
      icon: Icon(Icons.inventory_2_outlined),
      selectedIcon: Icon(Icons.inventory_2),
      label: 'Stock',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Customers',
    ),
    NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
  ];

  static const titles = <String>[
    'Business Today',
    'Sell',
    'Stock',
    'Customers',
    'More',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titles[index])),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AaraaSpacing.md),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Semantics(
                container: true,
                label: '${titles[index]} foundation screen',
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AaraaSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titles[index],
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AaraaSpacing.sm),
                        const Text(
                          'V0 foundation is ready. Transaction workflows arrive in the next milestone.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: destinations,
        onDestinationSelected: (value) => setState(() => index = value),
      ),
    );
  }
}
