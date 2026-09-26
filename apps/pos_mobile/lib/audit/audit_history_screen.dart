import 'package:flutter/material.dart';

import '../sell/local_pos_database.dart';
import 'audit_domain.dart';

class AuditHistoryScreen extends StatefulWidget {
  const AuditHistoryScreen({
    required this.database,
    super.key,
  });

  final LocalPosDatabase database;

  @override
  State<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends State<AuditHistoryScreen> {
  List<LocalAuditEvent> events = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final next = await widget.database.listAuditEvents(limit: 200);
    if (!mounted) return;
    setState(() {
      events = next;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.history_outlined),
              title: Text('Append-only local audit history'),
              subtitle: Text(
                'This records critical actions and their source entities. '
                'Financial amounts remain authoritative in their original ledgers.',
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (events.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No audit events yet'),
                subtitle: Text(
                  'New critical actions will appear here as they are recorded.',
                ),
              ),
            )
          else
            for (final event in events)
              Card(
                child: ListTile(
                  leading: Icon(_icon(event.action)),
                  title: Text(auditActionLabel(event.action)),
                  subtitle: Text(
                    [
                      auditEntityLabel(event),
                      _time(event.occurredAt),
                      'actor ${_short(event.actorUserId)}',
                    ].join(' • '),
                  ),
                  trailing: Chip(label: Text(event.outcome)),
                ),
              ),
        ],
      ),
    );
  }
}

IconData _icon(String action) {
  if (action.startsWith('sale.')) return Icons.receipt_long_outlined;
  if (action.startsWith('stock.')) return Icons.inventory_2_outlined;
  if (action.startsWith('shift.') || action.startsWith('cash.')) {
    return Icons.point_of_sale_outlined;
  }
  if (action.startsWith('expense.')) return Icons.payments_outlined;
  if (action.startsWith('employee.')) return Icons.badge_outlined;
  if (action.startsWith('supplier.')) return Icons.local_shipping_outlined;
  return Icons.history_outlined;
}

String _short(String value) =>
    value.length <= 8 ? value : value.substring(0, 8);

String _time(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
