import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import '../sync/sync_domain.dart';
import 'diagnostics_domain.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  LocalDiagnosticsSnapshot? snapshot;
  bool loading = true;
  bool allowed = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final canRead = await widget.database.canReadDiagnostics(
      widget.saleContext,
    );
    if (!canRead) {
      if (!mounted) return;
      setState(() {
        allowed = false;
        loading = false;
        snapshot = null;
      });
      return;
    }

    final next = await widget.database.diagnosticsSnapshot();
    if (!mounted) return;
    setState(() {
      allowed = true;
      loading = false;
      snapshot = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!allowed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Diagnostics are available only to the Owner or Manager.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final current = snapshot!;
    final age = current.unresolvedAge(DateTime.now());

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                current.needsAttention
                    ? Icons.warning_amber_outlined
                    : Icons.check_circle_outline,
              ),
              title: Text(
                current.needsAttention
                    ? 'Diagnostics need attention'
                    : 'Local diagnostics look healthy',
              ),
              subtitle: const Text(
                'This view shows technical counts and status only. '
                'It does not expose customer names, receipts, notes or amounts.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Local database',
            children: [
              _Line(
                label: 'Integrity check',
                value: current.databaseIntegrityOk ? 'OK' : 'Needs review',
              ),
              _Line(
                label: 'Foreign keys',
                value: current.foreignKeysEnabled ? 'Enabled' : 'Disabled',
              ),
              _Line(
                label: 'Schema version',
                value: '${current.schemaVersion}',
              ),
              _Line(
                label: 'Products',
                value: '${current.productCount}',
              ),
              _Line(
                label: 'Finalized sales',
                value: '${current.finalizedSaleCount}',
              ),
              _Line(
                label: 'Audit events',
                value: '${current.auditEventCount}',
              ),
              _Line(
                label: 'Open shifts',
                value: '${current.openShiftCount}',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Section(
            title: 'Synchronization',
            children: [
              _Line(
                label: 'Pending',
                value:
                    '${current.outboxCounts[LocalSyncState.pending] ?? 0}',
              ),
              _Line(
                label: 'Sending',
                value:
                    '${current.outboxCounts[LocalSyncState.sending] ?? 0}',
              ),
              _Line(
                label: 'Conflict',
                value:
                    '${current.outboxCounts[LocalSyncState.conflict] ?? 0}',
              ),
              _Line(
                label: 'Rejected',
                value:
                    '${current.outboxCounts[LocalSyncState.rejected] ?? 0}',
              ),
              _Line(
                label: 'Unresolved total',
                value: '${current.unresolvedSyncCount}',
              ),
              _Line(
                label: 'Oldest unresolved age',
                value: _formatAge(age),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Repository-only diagnostics'),
              subtitle: Text(
                'Server connectivity, cloud database, payment providers, '
                'messaging providers and physical hardware are not tested '
                'from this local screen.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}

String _formatAge(Duration? age) {
  if (age == null) return 'None';
  if (age.inDays > 0) return '${age.inDays}d ${age.inHours % 24}h';
  if (age.inHours > 0) return '${age.inHours}h ${age.inMinutes % 60}m';
  if (age.inMinutes > 0) return '${age.inMinutes}m';
  return '<1m';
}
