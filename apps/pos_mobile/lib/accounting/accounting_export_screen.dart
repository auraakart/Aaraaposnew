import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../intelligence/owner_intelligence.dart';
import '../sell/local_pos_database.dart';
import '../sell/sale_domain.dart';
import 'accounting_domain.dart';

class AccountingExportScreen extends StatefulWidget {
  const AccountingExportScreen({
    required this.database,
    super.key,
  });

  final LocalPosDatabase database;

  @override
  State<AccountingExportScreen> createState() => _AccountingExportScreenState();
}

class _AccountingExportScreenState extends State<AccountingExportScreen> {
  ReportPeriod period = ReportPeriod.thisMonth;
  List<AccountingExportRow> rows = const [];
  AccountingExportManifest? manifest;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    setState(() => loading = true);
    final nextRows = await widget.database.accountingExportRows(period);
    final nextManifest = buildAccountingManifest(nextRows);
    if (!mounted) return;
    setState(() {
      rows = nextRows;
      manifest = nextManifest;
      loading = false;
    });
  }

  Future<void> selectPeriod(ReportPeriod next) async {
    if (next == period) return;
    setState(() => period = next);
    await refresh();
  }

  Future<void> copyCsv() async {
    final csv = accountingRowsToCsv(rows);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Accounting CSV copied.')),
    );
  }

  Future<void> shareCsv() async {
    final csv = accountingRowsToCsv(rows);
    await SharePlus.instance.share(
      ShareParams(
        text: csv,
        subject: 'AaraaPOS accounting export • ${reportPeriodLabel(period)}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = manifest;
    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<ReportPeriod>(
            segments: [
              for (final value in ReportPeriod.values)
                ButtonSegment(
                  value: value,
                  label: Text(reportPeriodLabel(value)),
                ),
            ],
            selected: {period},
            onSelectionChanged: (selection) => selectPeriod(selection.single),
          ),
          const SizedBox(height: 16),
          if (loading || summary == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(label: 'Sales', value: formatInr(summary.salesMinor)),
                _Metric(label: 'Returns', value: formatInr(summary.returnsMinor)),
                _Metric(
                  label: 'Purchases',
                  value: formatInr(summary.purchasesMinor),
                ),
                _Metric(
                  label: 'Expenses',
                  value: formatInr(summary.expensesMinor),
                ),
                _Metric(label: 'Rows', value: '${summary.rowCount}'),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax summary',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _Line('Taxable', formatInr(summary.taxableMinor)),
                    _Line('CGST', formatInr(summary.cgstMinor)),
                    _Line('SGST', formatInr(summary.sgstMinor)),
                    _Line('IGST', formatInr(summary.igstMinor)),
                    if (summary.unclassifiedTaxMinor > 0) ...[
                      _Line(
                        'Purchase tax not split',
                        formatInr(summary.unclassifiedTaxMinor),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Some purchase receipts store only total tax. '
                        'AaraaPOS exports that amount without guessing a CGST/SGST/IGST split.',
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: Text('Source-linked export'),
                subtitle: Text(
                  'Every row retains its source record and balance effect. '
                  'This is a portable business register, not a statutory filing or certified accounting ledger.',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: rows.isEmpty ? null : copyCsv,
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copy CSV'),
                ),
                FilledButton.icon(
                  onPressed: rows.isEmpty ? null : shareCsv,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share CSV'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Register preview',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              const Card(
                child: ListTile(
                  title: Text('No records in this period'),
                  subtitle: Text('Choose another period or record activity first.'),
                ),
              )
            else
              for (final row in rows.take(30))
                Card(
                  child: ListTile(
                    leading: Icon(_icon(row.kind)),
                    title: Text(
                      row.documentNumber ??
                          accountingRegisterLabel(row.kind),
                    ),
                    subtitle: Text(
                      [
                        accountingRegisterLabel(row.kind),
                        row.partyName ?? 'No party',
                        row.balanceEffect,
                        _date(row.occurredAt),
                      ].join(' • '),
                    ),
                    trailing: Text(formatInr(row.totalMinor)),
                  ),
                ),
            if (rows.length > 30)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  '${rows.length - 30} more row(s) are included in the CSV.',
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}

IconData _icon(AccountingRegisterKind kind) => switch (kind) {
      AccountingRegisterKind.sales => Icons.receipt_long_outlined,
      AccountingRegisterKind.returns => Icons.assignment_return_outlined,
      AccountingRegisterKind.purchases => Icons.local_shipping_outlined,
      AccountingRegisterKind.expenses => Icons.payments_outlined,
      AccountingRegisterKind.customerCredit => Icons.person_outline,
      AccountingRegisterKind.supplierLedger => Icons.account_balance_outlined,
    };

String _date(DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/'
      '${local.year}';
}
