enum ReportPeriod { today, yesterday, thisWeek, thisMonth }

class BusinessMetrics {
  const BusinessMetrics({
    required this.period,
    required this.salesMinor,
    required this.billCount,
    required this.moneyReceivedMinor,
    required this.moneyDueMinor,
    required this.expensesMinor,
    required this.lowStockCount,
    required this.costCoverageBps,
    required this.previousComparableSalesMinor,
    this.estimatedProfitMinor,
    this.latestCashVarianceMinor,
  });

  final ReportPeriod period;
  final int salesMinor;
  final int billCount;
  final int moneyReceivedMinor;
  final int moneyDueMinor;
  final int expensesMinor;
  final int lowStockCount;
  final int costCoverageBps;
  final int previousComparableSalesMinor;
  final int? estimatedProfitMinor;
  final int? latestCashVarianceMinor;
}

class BusinessTimelineItem {
  const BusinessTimelineItem({
    required this.occurredAt,
    required this.title,
    required this.type,
    this.amountMinor,
    this.detail,
  });

  final DateTime occurredAt;
  final String title;
  final String type;
  final int? amountMinor;
  final String? detail;
}

enum DataQualitySeverity { info, warning, critical }

class LocalDataQualityIssue {
  const LocalDataQualityIssue({
    required this.type,
    required this.message,
    required this.repairHint,
    required this.severity,
  });

  final String type;
  final String message;
  final String repairHint;
  final DataQualitySeverity severity;
}

({DateTime start, DateTime end}) periodRange(
  ReportPeriod period,
  DateTime now,
) {
  final local = now.toLocal();
  final today = DateTime(local.year, local.month, local.day);
  return switch (period) {
    ReportPeriod.today => (start: today, end: today.add(const Duration(days: 1))),
    ReportPeriod.yesterday => (
        start: today.subtract(const Duration(days: 1)),
        end: today,
      ),
    ReportPeriod.thisWeek => (
        start: today.subtract(Duration(days: local.weekday - 1)),
        end: today.add(const Duration(days: 1)),
      ),
    ReportPeriod.thisMonth => (
        start: DateTime(local.year, local.month),
        end: DateTime(local.year, local.month + 1),
      ),
  };
}

String reportPeriodLabel(ReportPeriod period) => switch (period) {
      ReportPeriod.today => 'Today',
      ReportPeriod.yesterday => 'Yesterday',
      ReportPeriod.thisWeek => 'This Week',
      ReportPeriod.thisMonth => 'This Month',
    };
