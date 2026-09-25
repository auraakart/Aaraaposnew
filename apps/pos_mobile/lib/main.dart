import 'package:flutter/material.dart';

import 'customers/customers_screen.dart';
import 'intelligence/business_today_screen.dart';
import 'inventory/stock_screen.dart';
import 'more/more_screen.dart';
import 'sell/bootstrap_screen.dart';
import 'sell/local_pos_database.dart';
import 'sell/sell_screen.dart';

void main() {
  runApp(AaraaPosApp());
}

class AaraaPosApp extends StatelessWidget {
  AaraaPosApp({LocalPosDatabase? database, super.key})
      : database = database ?? LocalPosDatabase();

  final LocalPosDatabase database;

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
      home: PosRoot(database: database),
    );
  }
}

class PosRoot extends StatefulWidget {
  const PosRoot({required this.database, super.key});

  final LocalPosDatabase database;

  @override
  State<PosRoot> createState() => _PosRootState();
}

class _PosRootState extends State<PosRoot> {
  LocalSaleContext? saleContext;
  Object? loadError;
  var ready = false;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      await widget.database.open();
      final context = await widget.database.loadContext();
      if (!mounted) {
        return;
      }
      setState(() {
        saleContext = context;
        ready = true;
      });
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          loadError = error;
          ready = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ready) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (loadError != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'AaraaPOS could not open local storage. Restart the app and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
      );
    }

    final contextValue = saleContext;
    if (contextValue == null) {
      return BootstrapScreen(
        database: widget.database,
        onComplete: (context) => setState(() => saleContext = context),
      );
    }

    return MainShell(database: widget.database, saleContext: contextValue);
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  var index = 0;

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
      appBar: AppBar(
        title: Text(titles[index]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                widget.saleContext.storeName,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: index == 0
          ? BusinessTodayScreen(database: widget.database)
          : index == 1
              ? SellScreen(
              database: widget.database,
              saleContext: widget.saleContext,
            )
          : index == 2
              ? StockScreen(
                  database: widget.database,
                  saleContext: widget.saleContext,
                )
              : index == 3
                  ? CustomersScreen(
                      database: widget.database,
                      saleContext: widget.saleContext,
                    )
                  : MoreScreen(
                      database: widget.database,
                      saleContext: widget.saleContext,
                    ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: destinations,
        onDestinationSelected: (value) => setState(() => index = value),
      ),
    );
  }
}

class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Semantics(
          container: true,
          label: '$title screen',
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '$title is planned for its roadmap milestone.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
