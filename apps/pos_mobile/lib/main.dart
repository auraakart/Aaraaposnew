import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'auth/local_sign_in_screen.dart';
import 'customers/customers_screen.dart';
import 'intelligence/business_today_screen.dart';
import 'inventory/stock_screen.dart';
import 'l10n/app_strings.dart';
import 'more/more_screen.dart';
import 'workspace/workspace_policy.dart';
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
  LocalSaleContext? baseContext;
  LocalAuthenticatedSession? session;
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
      final restored = context == null
          ? null
          : await widget.database.restoreLocalSession(
              baseContext: context,
            );
      if (!mounted) return;

      setState(() {
        baseContext = context;
        session = restored;
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

  Future<void> lockCurrentSession() async {
    final active = session;
    if (active == null) return;
    await widget.database.endLocalSession(context: active.context);
    if (!mounted) return;
    setState(() => session = null);
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

    final contextValue = baseContext;
    if (contextValue == null) {
      return BootstrapScreen(
        database: widget.database,
        onComplete: (context) => setState(() {
          baseContext = context;
          session = null;
        }),
      );
    }

    final activeSession = session;
    if (activeSession == null) {
      return LocalSignInScreen(
        database: widget.database,
        baseContext: contextValue,
        onAuthenticated: (next) => setState(() => session = next),
      );
    }

    return MainShell(
      database: widget.database,
      session: activeSession,
      onLock: () {
        lockCurrentSession();
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({
    required this.database,
    required this.session,
    required this.onLock,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalAuthenticatedSession session;
  final VoidCallback onLock;

  LocalSaleContext get saleContext => session.context;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late final List<WorkspaceDestination> workspaceDestinations;
  var index = 0;
  Timer? sessionTimer;

  @override
  void initState() {
    super.initState();
    workspaceDestinations = workspaceDestinationsForRole(widget.session.role);
    scheduleExpiry();
  }

  void scheduleExpiry() {
    sessionTimer?.cancel();
    final remaining =
        widget.session.expiresAt.difference(DateTime.now().toUtc());
    if (remaining <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLock();
      });
      return;
    }
    sessionTimer = Timer(remaining, widget.onLock);
  }

  @override
  void dispose() {
    sessionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final selected = workspaceDestinations[index];

    return Scaffold(
      appBar: AppBar(
        title: Text(_workspaceTitle(selected, strings)),
        actions: [
          Center(
            child: Text(
              widget.session.employeeName,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          IconButton(
            tooltip: 'Lock / switch user',
            onPressed: widget.onLock,
            icon: const Icon(Icons.lock_outline),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _workspaceBody(selected),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: [
          for (final destination in workspaceDestinations)
            _navigationDestination(destination, strings),
        ],
        onDestinationSelected: (value) => setState(() => index = value),
      ),
    );
  }

  NavigationDestination _navigationDestination(
    WorkspaceDestination destination,
    AppStrings strings,
  ) =>
      switch (destination) {
        WorkspaceDestination.home => NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.home,
          ),
        WorkspaceDestination.sell => NavigationDestination(
            icon: const Icon(Icons.point_of_sale_outlined),
            selectedIcon: const Icon(Icons.point_of_sale),
            label: strings.sell,
          ),
        WorkspaceDestination.stock => NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2),
            label: strings.stock,
          ),
        WorkspaceDestination.customers => NavigationDestination(
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: strings.customers,
          ),
        WorkspaceDestination.more => NavigationDestination(
            icon: const Icon(Icons.more_horiz),
            label: strings.more,
          ),
      };

  String _workspaceTitle(
    WorkspaceDestination destination,
    AppStrings strings,
  ) =>
      switch (destination) {
        WorkspaceDestination.home => strings.businessToday,
        WorkspaceDestination.sell => strings.sell,
        WorkspaceDestination.stock => strings.stock,
        WorkspaceDestination.customers => strings.customers,
        WorkspaceDestination.more => strings.more,
      };

  Widget _workspaceBody(WorkspaceDestination destination) =>
      switch (destination) {
        WorkspaceDestination.home =>
          BusinessTodayScreen(database: widget.database),
        WorkspaceDestination.sell => SellScreen(
            database: widget.database,
            saleContext: widget.saleContext,
          ),
        WorkspaceDestination.stock => StockScreen(
            database: widget.database,
            saleContext: widget.saleContext,
          ),
        WorkspaceDestination.customers => CustomersScreen(
            database: widget.database,
            saleContext: widget.saleContext,
          ),
        WorkspaceDestination.more => MoreScreen(
            database: widget.database,
            saleContext: widget.saleContext,
            role: widget.session.role,
            onSessionInvalidated: widget.onLock,
          ),
      };
}
