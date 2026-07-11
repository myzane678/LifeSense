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
  static const _legacySelectedIdsKey = 'digest_selected_interest_ids';
  static const _legacyMigratedKey = 'digest_selected_interest_ids_migrated';
  static const maxSelection = 3;
  static const defaultSelectedIds = ['frontier', 'study', 'career'];

  DigestPreferencesService({UserSettingsService? userSettingsService})
    : _userSettingsService =
          userSettingsService ?? UserSettingsService.instance;

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
      feedKey: 'healthLocal',
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

  final UserSettingsService _userSettingsService;

  bool _isInitialized = false;
  bool _promptSeen = false;
  String? _userId;
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

  String _selectedIdsKey(String uid) => 'digest_selected_interest_ids_$uid';
  String _syncPendingKey(String uid) => 'digest_interest_sync_pending_$uid';

  Future<void> initializeForUser(
    String uid, {
    UserSettingsRecord? cloudRecord,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    _userId = uid;
    _promptSeen = prefs.getBool(_promptSeenKey) ?? false;
    await _migrateLegacySelection(prefs, uid);

    final pending = prefs.getBool(_syncPendingKey(uid)) ?? false;
    final localIds = prefs.getStringList(_selectedIdsKey(uid));
    if (pending && localIds != null) {
      _selectedIds = _sanitizeSelection(localIds);
      _isInitialized = true;
      notifyListeners();
      try {
        await _userSettingsService.saveDigestSelectedIds(uid, _selectedIds);
        await prefs.setBool(_syncPendingKey(uid), false);
      } catch (_) {}
      return;
    }

    final cloudIds = cloudRecord?.digestSelectedIds;
    final nextSelectedIds = _sanitizeSelection(
      cloudIds != null && cloudIds.isNotEmpty
          ? cloudIds
          : (localIds ?? defaultSelectedIds),
    );
    final changed = !_isInitialized || !_sameIds(_selectedIds, nextSelectedIds);
    _selectedIds = nextSelectedIds;
    _isInitialized = true;
    await prefs.setStringList(_selectedIdsKey(uid), nextSelectedIds);
    if (changed) notifyListeners();
  }

  Future<void> markPromptSeen() async {
    final prefs = await SharedPreferences.getInstance();
    _promptSeen = true;
    await prefs.setBool(_promptSeenKey, true);
    notifyListeners();
  }

  Future<void> setSelectedIds(List<String> ids) async {
    final uid = _userId;
    if (uid == null) {
      throw StateError('兴趣方向尚未初始化');
    }
    final sanitized = _sanitizeSelection(ids);
    final prefs = await SharedPreferences.getInstance();
    _selectedIds = sanitized;
    await prefs.setStringList(_selectedIdsKey(uid), sanitized);
    await prefs.setBool(_syncPendingKey(uid), true);
    notifyListeners();
    try {
      await _userSettingsService.saveDigestSelectedIds(uid, sanitized);
      await prefs.setBool(_syncPendingKey(uid), false);
    } catch (_) {
      rethrow;
    }
  }

  Future<void> retryPendingSync() async {
    final uid = _userId;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_syncPendingKey(uid)) ?? false)) return;
    await _userSettingsService.saveDigestSelectedIds(uid, _selectedIds);
    await prefs.setBool(_syncPendingKey(uid), false);
  }

  Future<void> clearForUser(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_selectedIdsKey(uid));
    await prefs.remove(_syncPendingKey(uid));
    if (_userId == uid) {
      _selectedIds = List.of(defaultSelectedIds);
      _isInitialized = true;
      notifyListeners();
    }
  }

  void resetSession() {
    _userId = null;
    _isInitialized = false;
    _selectedIds = List.of(defaultSelectedIds);
    notifyListeners();
  }

  Future<void> _migrateLegacySelection(
    SharedPreferences prefs,
    String uid,
  ) async {
    if (prefs.containsKey(_selectedIdsKey(uid)) ||
        (prefs.getBool(_legacyMigratedKey) ?? false)) {
      return;
    }
    final legacy = prefs.getStringList(_legacySelectedIdsKey);
    if (legacy != null) {
      await prefs.setStringList(
        _selectedIdsKey(uid),
        _sanitizeSelection(legacy),
      );
    }
    await prefs.setBool(_legacyMigratedKey, true);
  }

  static bool _sameIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
