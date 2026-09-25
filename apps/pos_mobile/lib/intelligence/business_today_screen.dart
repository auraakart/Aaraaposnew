import 'package:flutter/material.dart';

import '../ai/business_assistant_screen.dart';
import '../sell/local_pos_database.dart';
import '../sell/sale_domain.dart';
import 'owner_intelligence.dart';

class BusinessTodayScreen extends StatefulWidget {
  const BusinessTodayScreen({required this.database, super.key});

  final LocalPosDatabase database;

  @override
  State<BusinessTodayScreen> createState() => _BusinessTodayScreenState();
}

class _BusinessTodayScreenState extends State<BusinessTodayScreen> {
  ReportPeriod period = ReportPeriod.today;
  BusinessMetrics? metrics;
  List<BusinessTimelineItem> timeline = const [];
  List<LocalDataQualityIssue> qualityIssues = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final nextMetrics = await widget.database.businessMetrics(period);
    final nextTimeline = await widget.database.businessTimeline(limit: 20);
    final nextIssues = await widget.database.dataQualityIssues();
    if (!mounted) return;
    setState(() {
      metrics = nextMetrics;
      timeline = nextTimeline;
      qualityIssues = nextIssues;
      loading = false;
    });
  }

  Future<void> selectPeriod(ReportPeriod value) async {
    if (value == period) return;
    setState(() {
      period = value;
      loading = true;
    });
    await refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (loading || metrics == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = metrics!;

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ReportPeriod>(
              segments: [
                for (final value in ReportPeriod.values)
                  ButtonSegment(
                    value: value,
                    label: Text(reportPeriodLabel(value)),
                  ),
              ],
              selected: {period},
              onSelectionChanged: (values) => selectPeriod(values.first),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: const Text('Ask AaraaPOS'),
              subtitle: const Text(
                'Ask about sales, stock, customer credit, expenses or what to order',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BusinessAssistantScreen(
                      database: widget.database,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _MetricGrid(metrics: data),
          const SizedBox(height: 16),
          ..._alerts(context, data),
          if (qualityIssues.isNotEmpty) ...[
            Card(
              child: ExpansionTile(
                leading: const Icon(Icons.fact_check_outlined),
                title: Text('${qualityIssues.length} data-quality item'
                    '${qualityIssues.length == 1 ? '' : 's'}'),
                subtitle: const Text('Review issues before they affect reports.'),
                children: [
                  for (final issue in qualityIssues)
                    ListTile(
                      leading: Icon(_qualityIcon(issue.severity)),
                      title: Text(issue.message),
                      subtitle: Text(issue.repairHint),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'Business Timeline',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (timeline.isEmpty)
            const Card(
              child: ListTile(
                title: Text('No business activity yet'),
                subtitle: Text('Sales, purchases and shifts will appear here.'),
              ),
            ),
          for (final item in timeline)
            ListTile(
              leading: Icon(_timelineIcon(item.type)),
              title: Text(item.title),
              subtitle: Text(_timelineSubtitle(item)),
              trailing: item.amountMinor == null
                  ? null
                  : Text(
                      formatInr(item.amountMinor!),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
            ),
        ],
      ),
    );
  }

  List<Widget> _alerts(BuildContext context, BusinessMetrics data) {
    final alerts = <Widget>[];

    if (data.lowStockCount > 0) {
      alerts.add(
        _AlertCard(
          icon: Icons.inventory_2_outlined,
          title: '${data.lowStockCount} item'
              '${data.lowStockCount == 1 ? '' : 's'} need stock attention',
          message: 'Open Stock to count or replenish them.',
        ),
      );
    }

    if (data.moneyDueMinor > 0) {
      alerts.add(
        _AlertCard(
          icon: Icons.schedule_send_outlined,
          title: '${formatInr(data.moneyDueMinor)} customer credit is open',
          message: 'Open Customers to review balances and collections.',
        ),
      );
    }

    final variance = data.latestCashVarianceMinor;
    if (variance != null && variance != 0) {
      alerts.add(
        _AlertCard(
          icon: Icons.point_of_sale_outlined,
          title: 'Cash difference recorded: ${formatInr(variance.abs())}',
          message: variance < 0
              ? 'The latest closed shift was short.'
              : 'The latest closed shift had extra cash.',
        ),
      );
    }

    if (data.previousComparableSalesMinor > 0 &&
        data.salesMinor < data.previousComparableSalesMinor) {
      final difference = data.previousComparableSalesMinor - data.salesMinor;
      alerts.add(
        _AlertCard(
          icon: Icons.trending_down,
          title: 'Sales are ${formatInr(difference)} lower',
          message: 'Compared with the same period one week earlier.',
        ),
      );
    }

    return alerts;
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final BusinessMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _MetricCard(label: 'Sales', value: formatInr(metrics.salesMinor)),
      _MetricCard(label: 'Bills', value: '${metrics.billCount}'),
      _MetricCard(
        label: 'Money Received',
        value: formatInr(metrics.moneyReceivedMinor),
      ),
      _MetricCard(
        label: 'Money Due',
        value: formatInr(metrics.moneyDueMinor),
      ),
      _MetricCard(
        label: 'Expenses',
        value: formatInr(metrics.expensesMinor),
      ),
      _MetricCard(
        label: 'Estimated Profit',
        value: metrics.estimatedProfitMinor == null
            ? 'Need cost data'
            : formatInr(metrics.estimatedProfitMinor!),
        detail: metrics.estimatedProfitMinor == null
            ? 'Cost coverage ${(metrics.costCoverageBps / 100).toStringAsFixed(0)}%'
            : 'Based on recorded purchase costs',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth > 700
            ? (constraints.maxWidth - 24) / 3
            : (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(message),
      ),
    );
  }
}

IconData _qualityIcon(DataQualitySeverity severity) => switch (severity) {
      DataQualitySeverity.info => Icons.info_outline,
      DataQualitySeverity.warning => Icons.warning_amber_outlined,
      DataQualitySeverity.critical => Icons.error_outline,
    };

IconData _timelineIcon(String type) => switch (type) {
      'sale' => Icons.receipt_long_outlined,
      'expense' => Icons.payments_outlined,
      'purchase_receipt' => Icons.inventory_2_outlined,
      'customer_credit' => Icons.schedule_send_outlined,
      'shift_open' => Icons.login,
      'shift_close' => Icons.logout,
      _ => Icons.circle_outlined,
    };

String _timelineSubtitle(BusinessTimelineItem item) {
  final local = item.occurredAt.toLocal();
  final time =
      '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
  return item.detail == null ? time : '$time • ${item.detail}';
}
