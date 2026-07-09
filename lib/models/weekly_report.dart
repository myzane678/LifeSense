import 'life_entry.dart';

class WeeklyReport {
  WeeklyReport({
    required this.weekLabel,
    required this.startDate,
    required this.endDate,
    required this.recordCount,
    required this.avgScore,
    required this.avgMood,
    required this.avgEnergy,
    required this.avgStress,
    required this.avgFocus,
    required this.avgSleep,
    required this.avgWater,
  });

  factory WeeklyReport.fromEntries(
    List<LifeEntry> entries,
    DateTime weekStart,
  ) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final count = entries.length;

    double avg(Iterable<num> values) =>
        values.fold<double>(0, (s, v) => s + v) / count;

    final label =
        '${weekStart.month}月${weekStart.day}日—${weekEnd.month}月${weekEnd.day}日';

    return WeeklyReport(
      weekLabel: label,
      startDate: weekStart,
      endDate: weekEnd,
      recordCount: count,
      avgScore: avg(entries.map((e) => e.score)).round(),
      avgMood: avg(entries.map((e) => e.mood)),
      avgEnergy: avg(entries.map((e) => e.energy)),
      avgStress: avg(entries.map((e) => e.stress)),
      avgFocus: avg(entries.map((e) => e.focus)),
      avgSleep: avg(entries.map((e) => e.sleepHours)),
      avgWater: avg(entries.map((e) => e.waterCups)),
    );
  }

  final String weekLabel;
  final DateTime startDate;
  final DateTime endDate;
  final int recordCount;
  final int avgScore;
  final double avgMood;
  final double avgEnergy;
  final double avgStress;
  final double avgFocus;
  final double avgSleep;
  final double avgWater;
}
