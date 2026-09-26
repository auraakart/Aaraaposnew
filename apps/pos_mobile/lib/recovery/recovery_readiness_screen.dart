import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import 'recovery_readiness.dart';

class RecoveryReadinessScreen extends StatefulWidget {
  const RecoveryReadinessScreen({
    required this.database,
    required this.saleContext,
    super.key,
  });

  final LocalPosDatabase database;
  final LocalSaleContext saleContext;

  @override
  State<RecoveryReadinessScreen> createState() =>
      _RecoveryReadinessScreenState();
}

class _RecoveryReadinessScreenState extends State<RecoveryReadinessScreen> {
  RecoveryReadiness? readiness;
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
        readiness = null;
      });
      return;
    }

    final diagnostics = await widget.database.diagnosticsSnapshot();
    if (!mounted) return;
    setState(() {
      allowed = true;
      loading = false;
      readiness = RecoveryReadiness.fromDiagnostics(diagnostics);
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
            'Recovery readiness is available only to the Owner or Manager.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final current = readiness!;

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: Icon(
                current.canEvaluateRestoreSafely
                    ? Icons.verified_outlined
                    : Icons.warning_amber_outlined,
              ),
              title: Text(
                current.canEvaluateRestoreSafely
                    ? 'Local state is safe for recovery assessment'
                    : 'Recovery assessment is currently blocked',
              ),
              subtitle: const Text(
                'AaraaPOS does not replace or restore local financial data '
                'while unresolved local writes exist.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Readiness checks',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _Line(
                    label: 'Database integrity',
                    value: current.databaseHealthy ? 'OK' : 'Needs review',
                  ),
                  _Line(
                    label: 'Foreign keys',
                    value: current.foreignKeysEnabled
                        ? 'Enabled'
                        : 'Disabled',
                  ),
                  _Line(
                    label: 'Schema version',
                    value: '${current.schemaVersion}',
                  ),
                  _Line(
                    label: 'Unresolved local writes',
                    value: '${current.unresolvedLocalWrites}',
                  ),
                  _Line(
                    label: 'Encrypted backup provider',
                    value: current.backupProviderConfigured
                        ? 'Configured'
                        : 'Not configured',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (current.blockers.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current blockers',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    for (final blocker in current.blockers)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text('• ${_label(blocker)}'),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Restore remains external and deliberate'),
              subtitle: Text(
                'This milestone validates readiness and checkpoint metadata only. '
                'It does not create a destructive restore button, upload backups, '
                'or claim encrypted cloud storage is configured.',
              ),
            ),
          ),
        ],
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

String _label(String code) => switch (code) {
      'LOCAL_DATABASE_INTEGRITY_FAILED' =>
        'Local database integrity check failed',
      'FOREIGN_KEYS_DISABLED' => 'Database foreign-key enforcement is disabled',
      'UNRESOLVED_LOCAL_WRITES' =>
        'Pending/conflict/rejected local writes must be resolved first',
      'BACKUP_PROVIDER_NOT_CONFIGURED' =>
        'Encrypted backup storage provider is not configured',
      _ => code,
    };
