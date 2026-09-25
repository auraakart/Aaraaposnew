import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import '../sync/sync_domain.dart';

class IntegrationStatusScreen extends StatefulWidget {
  const IntegrationStatusScreen({required this.database, super.key});

  final LocalPosDatabase database;

  @override
  State<IntegrationStatusScreen> createState() =>
      _IntegrationStatusScreenState();
}

class _IntegrationStatusScreenState extends State<IntegrationStatusScreen> {
  Map<LocalSyncState, int> counts = const {};
  List<LocalOutboxItem> items = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final nextCounts = await widget.database.outboxStateCounts();
    final nextItems = await widget.database.listOutboxItems(limit: 50);
    if (!mounted) return;
    setState(() {
      counts = nextCounts;
      items = nextItems;
      loading = false;
    });
  }

  Future<void> retry(LocalOutboxItem item) async {
    try {
      await widget.database.retryOutbox(item.id);
      await refresh();
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item cannot be retried from its current state.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(label: 'Pending', count: counts[LocalSyncState.pending] ?? 0),
              _StatusChip(label: 'Sending', count: counts[LocalSyncState.sending] ?? 0),
              _StatusChip(label: 'Conflict', count: counts[LocalSyncState.conflict] ?? 0),
              _StatusChip(label: 'Rejected', count: counts[LocalSyncState.rejected] ?? 0),
            ],
          ),
          const SizedBox(height: 16),
          const Card(
            child: ListTile(
              leading: Icon(Icons.payments_outlined),
              title: Text('Payment providers'),
              subtitle: Text(
                'Cash works locally. UPI and Card remain unavailable until a real provider declares the required capabilities.',
              ),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.webhook_outlined),
              title: Text('Provider callbacks'),
              subtitle: Text(
                'Server contracts require signed, fresh, deduplicated webhook events. No provider webhook is configured in this build.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Sync queue', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text('No unresolved sync items'),
                subtitle: Text('Acknowledged history is retained outside this unresolved view.'),
              ),
            ),
          for (final item in items)
            Card(
              child: ListTile(
                leading: Icon(_icon(item.state)),
                title: Text('${item.entityType} • ${_label(item.state)}'),
                subtitle: Text(
                  [
                    'Attempts ${item.attemptCount}',
                    'Schema v${item.schemaVersion}',
                    if (item.serverMessage != null) item.serverMessage!,
                  ].join(' • '),
                ),
                trailing:
                    item.state == LocalSyncState.conflict ||
                            item.state == LocalSyncState.rejected
                        ? TextButton(
                            onPressed: () => retry(item),
                            child: const Text('Retry'),
                          )
                        : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(label: Text('$label $count'));
  }
}

String _label(LocalSyncState state) => switch (state) {
      LocalSyncState.pending => 'Pending',
      LocalSyncState.sending => 'Sending',
      LocalSyncState.acknowledged => 'Acknowledged',
      LocalSyncState.conflict => 'Conflict',
      LocalSyncState.rejected => 'Rejected',
    };

IconData _icon(LocalSyncState state) => switch (state) {
      LocalSyncState.pending => Icons.schedule_outlined,
      LocalSyncState.sending => Icons.cloud_upload_outlined,
      LocalSyncState.acknowledged => Icons.check_circle_outline,
      LocalSyncState.conflict => Icons.sync_problem_outlined,
      LocalSyncState.rejected => Icons.block_outlined,
    };
