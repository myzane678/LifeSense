class LifeScoreService {
  int calculateScore({
    required int mood,
    required int energy,
    required int stress,
    required int focus,
    required double sleepHours,
    required int waterCups,
  }) {
    final sleepScore = _sleepScore(sleepHours);
    final waterScore = _waterScore(waterCups);
    final rawScore =
        mood * 10 +
        energy * 10 +
        focus * 10 +
        sleepScore +
        waterScore -
        stress * 8;
    return rawScore.clamp(0, 100).round();
  }

  String statusFor({
    required int score,
    required int energy,
    required int stress,
    required double sleepHours,
  }) {
    if (stress >= 4) return '压力偏高';
    if (sleepHours < 6) return '需要休息';
    if (energy <= 2) return '精力不足';
    if (score >= 80) return '状态良好';
    return '状态普通';
  }

  String suggestionFor({
    required int mood,
    required int energy,
    required int stress,
    required int focus,
    required double sleepHours,
    required int waterCups,
    required int score,
  }) {
    if (stress >= 4 && sleepHours < 6) {
      return '今天压力和睡眠都不太理想，晚上优先休息，先把任务量降一点。';
    }
    if (energy <= 2 && waterCups < 4) {
      return '精力偏低且饮水较少，先喝点水，再走动 5 分钟恢复状态。';
    }
    if (focus <= 2 && stress >= 4) {
      return '专注度受压力影响明显，可以先做 25 分钟小任务，再休息一下。';
    }
    if (sleepHours < 6) {
      return '睡眠时间偏少，今天尽量减少熬夜，安排一个更早的休息时间。';
    }
    if (score >= 80) {
      return '今天整体状态不错，保持现在的节奏就很好。';
    }
    if (mood <= 2) {
      return '心情有些低落，给自己安排一件轻松的小事，先把状态拉回来。';
    }
    return '今天状态比较平稳，建议完成一个明确的小目标并及时休息。';
  }

  int _sleepScore(double sleepHours) {
    if (sleepHours >= 7 && sleepHours <= 8.5) return 25;
    if (sleepHours >= 6 && sleepHours < 7) return 18;
    if (sleepHours > 8.5 && sleepHours <= 10) return 18;
    if (sleepHours >= 5 && sleepHours < 6) return 10;
    return 5;
  }

  int _waterScore(int waterCups) {
    if (waterCups >= 6 && waterCups <= 8) return 15;
    if (waterCups >= 4 && waterCups < 6) return 10;
    if (waterCups > 8) return 12;
    return 5;
  }
}
