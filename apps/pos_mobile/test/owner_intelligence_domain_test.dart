import 'package:aaraapos_pos/intelligence/owner_intelligence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('today range uses local calendar boundary', () {
    final range = periodRange(
      ReportPeriod.today,
      DateTime(2026, 9, 25, 15, 30),
    );

    expect(range.start, DateTime(2026, 9, 25));
    expect(range.end, DateTime(2026, 9, 26));
  });

  test('week starts on Monday', () {
    final range = periodRange(
      ReportPeriod.thisWeek,
      DateTime(2026, 9, 25),
    );

    expect(range.start.weekday, DateTime.monday);
    expect(range.end, DateTime(2026, 9, 26));
  });
}
