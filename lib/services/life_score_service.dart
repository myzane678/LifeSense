// 评分权重来源：PHQ-9、GAD-7、WHO-5、DASS-21、PSQI 等循证量表
// 各维度满分加总恰好 100，无需 clamp
class LifeScoreService {
  int calculateScore({
    required int mood,
    required int energy,
    required int stress,
    required int focus,
    required double sleepHours,
    required int waterCups,
  }) {
    return _moodScore(mood) +
        _stressScore(stress) +
        _energyScore(energy) +
        _sleepScore(sleepHours) +
        _focusScore(focus) +
        _waterScore(waterCups);
  }

  String statusFor({
    required int score,
    required int energy,
    required int stress,
    required double sleepHours,
  }) {
    if (stress >= 4 && sleepHours < 6) return '压力与睡眠双重预警';
    if (stress >= 4) return '压力偏高';
    if (sleepHours < 6) return '需要休息';
    if (energy <= 2) return '精力不足';
    if (score >= 85) return '状态极佳';
    if (score >= 70) return '状态良好';
    if (score >= 55) return '状态普通';
    if (score >= 40) return '状态欠佳';
    return '需要关注';
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
    // 压力 + 睡眠双重预警
    if (stress >= 4 && sleepHours < 6) {
      return '今天压力和睡眠都亮红灯，建议：\n'
          '① 现在用 4-7-8 呼吸法放松：吸气 4 秒→屏息 7 秒→呼气 8 秒，重复 4 次\n'
          '② 今晚 22:30 前放下手机，把明天的待办写在纸上清空大脑\n'
          '③ 明天任务列表只保留最重要的 1-2 件，其余推迟';
    }
    // 睡眠不足
    if (sleepHours < 6) {
      return '睡眠不足 6 小时，建议今晚：\n'
          '① 睡前 1 小时停用手机/电脑，把屏幕亮度调到最低\n'
          '② 室温调到 18-22°C，拉上遮光窗帘\n'
          '③ 用 10 分钟写下明天要做的事，释放"待机焦虑"后再上床';
    }
    // 压力高
    if (stress >= 4) {
      return '压力指数偏高，可以立刻试试：\n'
          '① 5 分钟方盒呼吸：吸气 4 秒→屏息 4 秒→呼气 4 秒→屏息 4 秒，循环 5 组\n'
          '② 起身走动 5-10 分钟，可以倒杯水或做 10 个深蹲\n'
          '③ 把当前最让你焦虑的一件事写下来，拆成最小的第一步去执行';
    }
    // 精力低 + 饮水不足
    if (energy <= 2 && waterCups < 4) {
      return '精力低且饮水不足，脱水会让疲劳感加倍，建议：\n'
          '① 现在喝 300-500 ml 水（不是咖啡或饮料）\n'
          '② 站起来做 1 分钟原地踏步或颈肩转动，激活循环\n'
          '③ 之后每 1 小时设一个喝水提醒，目标今天共喝 8 杯';
    }
    // 专注差 + 压力中等
    if (focus <= 2 && stress >= 3) {
      return '专注力受压力干扰，推荐用番茄工作法：\n'
          '① 设定 25 分钟计时器，只做一件事，屏蔽所有通知\n'
          '② 25 分钟结束后强制休息 5 分钟（站起来、看远处）\n'
          '③ 每完成 4 个番茄钟休息 15-30 分钟，今天目标 2-3 个即可';
    }
    // 心情低落
    if (mood <= 2) {
      return '心情比较低落，几个可以立刻做的事：\n'
          '① 出门晒 10-15 分钟太阳，光照可以促进血清素分泌\n'
          '② 联系一个让你轻松的朋友，发条消息或打个短电话\n'
          '③ 做一件今天最小的"完成感"任务（整理桌面、回复一封邮件等）';
    }
    // 精力低
    if (energy <= 2) {
      return '精力偏低，建议：\n'
          '① 检查最近睡眠和饮水是否达标（目标 7h 睡眠、8 杯水）\n'
          '② 下午 2-3 点若犯困，可小睡 10-20 分钟（不要超过 30 分钟）\n'
          '③ 减少高碳水零食，优先选择坚果、鸡蛋等提供持续能量的食物';
    }
    // 饮水不足
    if (waterCups <= 3) {
      return '今天饮水偏少，轻度脱水即会影响注意力和情绪，建议：\n'
          '① 现在喝一杯 300 ml 的水\n'
          '② 在手机设 2-3 个喝水提醒（10:00、14:00、17:00）\n'
          '③ 桌上放一个 500 ml 水杯作为视觉提示，目标喝空 3 次';
    }
    // 专注差（单独）
    if (focus <= 2) {
      return '专注力有些分散，可以试试：\n'
          '① 清理桌面上的无关物品，只留当前任务相关的东西\n'
          '② 把手机调成勿扰模式，放到够不到的地方\n'
          '③ 用"两分钟法则"：能在 2 分钟内完成的事立刻做掉，其余写进清单';
    }
    // 高分
    if (score >= 85) {
      return '今天状态极佳，趁状态好做最重要的事：\n'
          '① 把今天最难、最重要的任务排在上午精力最旺的时段\n'
          '② 保持当前的睡眠和饮水节奏，这是高分的关键\n'
          '③ 适当记录一下今天的好状态是怎么来的，方便之后复现';
    }
    if (score >= 70) {
      return '今天状态不错，保持节奏：\n'
          '① 确保今晚 7-9 小时睡眠，维持这个状态\n'
          '② 每工作 50-60 分钟起身活动 5 分钟，防止状态下滑\n'
          '③ 睡前记录一件今天做得好的事，有助于积累正向情绪';
    }
    // 默认
    return '今天状态平稳，可以这样保持：\n'
        '① 今天选定 1-3 个明确目标，完成后打勾，建立成就感\n'
        '② 午休或下午喝一杯水并走动 5 分钟，防止状态下滑\n'
        '③ 晚上 23:00 前上床，保证明天有充足精力';
  }

  // 心情：22分满分（WHO-5 正向情感核心指标）
  int _moodScore(int mood) {
    return switch (mood) {
      5 => 22,
      4 => 18,
      3 => 13,
      2 => 7,
      _ => 2,
    };
  }

  // 压力反向：20分满分（DASS-21 独立维度，最强负向因素）
  int _stressScore(int stress) {
    return switch (stress) {
      1 => 20,
      2 => 16,
      3 => 11,
      4 => 5,
      _ => 1,
    };
  }

  // 精力：18分满分（PHQ-9 第4项：疲劳/精力不足）
  int _energyScore(int energy) {
    return switch (energy) {
      5 => 18,
      4 => 14,
      3 => 10,
      2 => 5,
      _ => 1,
    };
  }

  // 睡眠：15分满分（PSQI：7-9h 最优，<6h 风险显著）
  int _sleepScore(double h) {
    if (h >= 7 && h <= 9) return 15;
    if (h >= 6 && h < 7) return 11;
    if (h > 9 && h <= 10) return 11;
    if (h >= 5 && h < 6) return 7;
    if (h > 10) return 7;
    return 3;
  }

  // 专注：15分满分（PHQ-9 第7项：注意力集中困难）
  int _focusScore(int focus) {
    return switch (focus) {
      5 => 15,
      4 => 12,
      3 => 9,
      2 => 5,
      _ => 1,
    };
  }

  // 饮水：10分满分（伊朗样本研究：<2杯/天抑郁风险翻倍）
  int _waterScore(int cups) {
    if (cups >= 8) return 10;
    if (cups >= 6) return 9;
    if (cups >= 4) return 7;
    if (cups >= 2) return 4;
    return 1;
  }
}
