import 'package:flutter/material.dart';

import '../multistore/store_scope_screen.dart';
import '../operations/operations_screen.dart';
import '../purchases/purchases_screen.dart';
import '../returns/returns_screen.dart';
import '../sell/local_pos_database.dart';

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
