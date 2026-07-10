import 'package:flutter_test/flutter_test.dart';
import 'package:life_sense/services/life_score_service.dart';

void main() {
  final service = LifeScoreService();

  test('健康状态会得到较高分数', () {
    final score = service.calculateScore(
      mood: 5,
      energy: 5,
      stress: 1,
      focus: 5,
      sleepHours: 7.5,
      waterCups: 7,
    );

    expect(score, greaterThanOrEqualTo(80));
  });

  test('睡眠不足会给出休息建议', () {
    final score = service.calculateScore(
      mood: 3,
      energy: 3,
      stress: 2,
      focus: 3,
      sleepHours: 5,
      waterCups: 6,
    );

    expect(
      service.suggestionFor(
        mood: 3,
        energy: 3,
        stress: 2,
        focus: 3,
        sleepHours: 5,
        waterCups: 6,
        score: score,
      ),
      contains('睡眠'),
    );
  });

  test('分数限制在 0 到 100', () {
    final score = service.calculateScore(
      mood: 1,
      energy: 1,
      stress: 5,
      focus: 1,
      sleepHours: 0,
      waterCups: 0,
    );

    expect(score, inInclusiveRange(0, 100));
  });
  test('饮水建议不会显示已经过去的提醒时间', () {
    final score = service.calculateScore(
      mood: 3,
      energy: 3,
      stress: 2,
      focus: 3,
      sleepHours: 7,
      waterCups: 0,
    );

    final suggestion = service.suggestionFor(
      mood: 3,
      energy: 3,
      stress: 2,
      focus: 3,
      sleepHours: 7,
      waterCups: 0,
      score: score,
      now: DateTime(2026, 7, 10, 10, 6),
    );

    expect(suggestion, isNot(contains('10:00')));
    expect(suggestion, contains('14:00'));
    expect(suggestion, contains('17:00'));
  });
}
