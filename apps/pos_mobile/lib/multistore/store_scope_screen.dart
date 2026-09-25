import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';

class StoreScopeScreen extends StatelessWidget {
  const StoreScopeScreen({
    required this.saleContext,
    super.key,
  });

  final LocalSaleContext saleContext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  saleContext.storeName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text('Terminal ${saleContext.terminalCode}'),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.offline_bolt_outlined),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This POS terminal stays bound to one store while offline.',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: ListTile(
            leading: Icon(Icons.security_outlined),
            title: Text('Store isolation'),
            subtitle: Text(
              'Sales, stock, shifts and cash on this device belong to this store only. '
              'A user cannot switch the offline database to another store by changing a filter.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.swap_horiz),
            title: Text('Inter-store transfers'),
            subtitle: Text(
              'Transfers use authorized source and destination store records. '
              'Dispatch removes stock from the source; receipt adds stock to the destination.',
            ),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.cloud_sync_outlined),
            title: Text('Other stores'),
            subtitle: Text(
              'Owner multi-store summaries and destination-store receipt require authenticated '
              'server synchronization. Offline billing never depends on that connection.',
            ),
          ),
        ),
      ],
    );
  }
}
