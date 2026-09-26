import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'customers/customers_screen.dart';
import 'intelligence/business_today_screen.dart';
import 'inventory/stock_screen.dart';
import 'l10n/app_strings.dart';
import 'more/more_screen.dart';
import 'sell/bootstrap_screen.dart';
import 'sell/local_pos_database.dart';
import 'sell/sell_screen.dart';

void main() {
  runApp(AaraaPosApp());
}

class AaraaPosApp extends StatefulWidget {
  AaraaPosApp({LocalPosDatabase? database, super.key})
      : database = database ?? LocalPosDatabase();

  final LocalPosDatabase database;

  @override
  State<AaraaPosApp> createState() => _AaraaPosAppState();
}

class _AaraaPosAppState extends State<AaraaPosApp> {
  final AppLocaleController localeController = AppLocaleController();

  @override
  void dispose() {
    localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF006B5F),
      brightness: Brightness.light,
    );

    return AnimatedBuilder(
      animation: localeController,
      builder: (context, _) => AppLocaleScope(
        controller: localeController,
        child: MaterialApp(
          title: 'AaraaPOS',
          debugShowCheckedModeBanner: false,
          locale: localeController.locale,
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
          home: PosRoot(
            database: widget.database,
            localeController: localeController,
          ),
        ),
      ),
    );
  }
}

class PosRoot extends StatefulWidget {
  const PosRoot({
    required this.database,
    required this.localeController,
    super.key,
  });

  final LocalPosDatabase database;
  final AppLocaleController localeController;

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
      widget.localeController.loadPreferredCode(context?.preferredLocaleCode);
      if (!mounted) return;

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
              AppStrings.of(context).localStorageError,
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

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: strings.home,
      ),
      NavigationDestination(
        icon: const Icon(Icons.point_of_sale_outlined),
        selectedIcon: const Icon(Icons.point_of_sale),
        label: strings.sell,
      ),
      NavigationDestination(
        icon: const Icon(Icons.inventory_2_outlined),
        selectedIcon: const Icon(Icons.inventory_2),
        label: strings.stock,
      ),
      NavigationDestination(
        icon: const Icon(Icons.people_outline),
        selectedIcon: const Icon(Icons.people),
        label: strings.customers,
      ),
      NavigationDestination(
        icon: const Icon(Icons.more_horiz),
        label: strings.more,
      ),
    ];
    final titles = <String>[
      strings.businessToday,
      strings.sell,
      strings.stock,
      strings.customers,
      strings.more,
    ];

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
