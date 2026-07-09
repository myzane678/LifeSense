class LifeEntry {
  const LifeEntry({
    required this.id,
    required this.createdAt,
    required this.mood,
    required this.energy,
    required this.stress,
    required this.focus,
    required this.sleepHours,
    required this.waterCups,
    required this.activity,
    required this.note,
    required this.score,
    required this.status,
    required this.suggestion,
  });

  final String id;
  final DateTime createdAt;
  final int mood;
  final int energy;
  final int stress;
  final int focus;
  final double sleepHours;
  final int waterCups;
  final String activity;
  final String note;
  final int score;
  final String status;
  final String suggestion;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'mood': mood,
      'energy': energy,
      'stress': stress,
      'focus': focus,
      'sleepHours': sleepHours,
      'waterCups': waterCups,
      'activity': activity,
      'note': note,
      'score': score,
      'status': status,
      'suggestion': suggestion,
    };
  }

  factory LifeEntry.fromJson(Map<String, dynamic> json) {
    return LifeEntry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      mood: json['mood'] as int,
      energy: json['energy'] as int,
      stress: json['stress'] as int,
      focus: json['focus'] as int,
      sleepHours: (json['sleepHours'] as num).toDouble(),
      waterCups: json['waterCups'] as int,
      activity: json['activity'] as String,
      note: json['note'] as String,
      score: json['score'] as int,
      status: json['status'] as String,
      suggestion: json['suggestion'] as String,
    );
  }

  bool get isToday {
    final now = DateTime.now();
    return createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
  }
}
