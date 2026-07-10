import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_settings_service.dart';

class DigestInterest {
  const DigestInterest({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.feedKey,
    required this.icon,
  });

  final String id;
  final String label;
  final String subtitle;
  final String feedKey;
  final IconData icon;
}

class DigestPreferencesService extends ChangeNotifier {
  static const _promptSeenKey = 'digest_interest_prompt_seen';
  static const _selectedIdsKey = 'digest_selected_interest_ids';
  static const maxSelection = 3;
  static const defaultSelectedIds = ['frontier', 'study', 'career'];

  static const interests = [
    DigestInterest(
      id: 'frontier',
      label: '前沿科技',
      subtitle: 'AI、芯片、航天与硬科技',
      feedKey: 'frontier',
      icon: Icons.auto_awesome_outlined,
    ),
    DigestInterest(
      id: 'study',
      label: '学习方法',
      subtitle: '复习、专注、笔记与考试策略',
      feedKey: 'study',
      icon: Icons.school_outlined,
    ),
    DigestInterest(
      id: 'health',
      label: '健康生活',
      subtitle: '作息、运动与身心状态',
      feedKey: 'tips',
      icon: Icons.favorite_border,
    ),
    DigestInterest(
      id: 'business',
      label: '商业财经',
      subtitle: '公司、消费、产业与市场',
      feedKey: 'business',
      icon: Icons.trending_up_outlined,
    ),
    DigestInterest(
      id: 'career',
      label: '职业发展',
      subtitle: '就业、实习、成长与长期规划',
      feedKey: 'career',
      icon: Icons.work_outline,
    ),
    DigestInterest(
      id: 'product',
      label: '产品设计',
      subtitle: '体验、交互、创意与产品思考',
      feedKey: 'product',
      icon: Icons.design_services_outlined,
    ),
    DigestInterest(
      id: 'campus',
      label: '校园成长',
      subtitle: '竞赛、考研、毕业与学生视角',
      feedKey: 'campus',
      icon: Icons.local_library_outlined,
    ),
    DigestInterest(
      id: 'politics',
      label: '时政热点',
      subtitle: '国内要闻、社会动态与政策资讯',
      feedKey: 'politics',
      icon: Icons.account_balance_outlined,
    ),
  ];

  bool _isInitialized = false;
  bool _promptSeen = false;
  List<String> _selectedIds = List.of(defaultSelectedIds);

  bool get isInitialized => _isInitialized;
  bool get promptSeen => _promptSeen;
  List<String> get selectedIds => List.unmodifiable(_selectedIds);
  List<DigestInterest> get selectedInterests => _selectedIds
      .map(interestById)
      .whereType<DigestInterest>()
      .toList(growable: false);

  String get selectedLabelText =>
      selectedInterests.map((e) => e.label).join('、');

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _promptSeen = prefs.getBool(_promptSeenKey) ?? false;
    final storedIds = prefs.getStringList(_selectedIdsKey);
    _selectedIds = _sanitizeSelection(storedIds ?? defaultSelectedIds);
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> markPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    _promptSeen = true;
    await prefs.setBool(_promptSeenKey, true);
    notifyListeners();
  }

  Future<void> setSelectedIds(List<String> ids) async {
    final sanitized = _sanitizeSelection(ids);
    final prefs = await SharedPreferences.getInstance();
    _selectedIds = sanitized;
    await prefs.setStringList(_selectedIdsKey, sanitized);
    notifyListeners();
    UserSettingsService.instance.syncToCloud();
  }

  static DigestInterest? interestById(String id) {
    for (final interest in interests) {
      if (interest.id == id) return interest;
    }
    return null;
  }

  static List<String> _sanitizeSelection(List<String> ids) {
    final knownIds = interests.map((e) => e.id).toSet();
    final legacyIds = {
      'tech': 'frontier',
      'ai': 'frontier',
      'finance': 'business',
      'design': 'product',
    };
    final result = <String>[];
    for (final id in ids) {
      final normalizedId = legacyIds[id] ?? id;
      if (!knownIds.contains(normalizedId) || result.contains(normalizedId)) {
        continue;
      }
      result.add(normalizedId);
      if (result.length == maxSelection) break;
    }
    return result.isEmpty ? List.of(defaultSelectedIds) : result;
  }
}
