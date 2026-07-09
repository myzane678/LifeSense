import 'dart:io';

import 'package:agconnect_auth/agconnect_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/avatar_storage_service.dart';
import '../services/profile_service.dart';

class ProfileProvider extends ChangeNotifier {
  static const _nicknameKey = 'profile_nickname';
  static const _avatarPathKey = 'profile_avatar_path';

  final ProfileService _profileService = ProfileService();

  String _nickname = '';
  String? _avatarPath;

  String get nickname => _nickname;
  String? get avatarPath => _avatarPath;
  bool get hasNickname => _nickname.trim().isNotEmpty;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _nickname = prefs.getString(_nicknameKey) ?? '';
    _avatarPath = prefs.getString(_avatarPathKey);
    notifyListeners();
  }

  Future<void> loadCloudProfile() async {
    try {
      final user = await AGCAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null) return;

      final profile = await _profileService.loadProfile();
      if (profile == null) return;

      final prefs = await SharedPreferences.getInstance();
      _nickname = profile.nickname;
      await prefs.setString(_nicknameKey, _nickname);
      notifyListeners();

      // 头像：用 uid 推导云端路径，本机缓存不存在时下载
      await _syncAvatarFromCloud(uid, prefs);
    } catch (_) {}
  }

  Future<void> _syncAvatarFromCloud(String uid, SharedPreferences prefs) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final localPath = '${directory.path}/avatar_cloud_$uid.jpg';
      final file = File(localPath);
      if (!await file.exists()) {
        await AvatarStorageService.instance.downloadAvatar(uid, localPath);
      }
      _avatarPath = localPath;
      await prefs.setString(_avatarPathKey, localPath);
      notifyListeners();
    } catch (_) {
      // 云端没有头像时静默忽略
    }
  }

  Future<void> setNickname(String nickname) async {
    _nickname = nickname.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_nicknameKey, _nickname);
    notifyListeners();
    await _profileService.saveProfile(
      nickname: _nickname,
      avatarPath: _avatarPath ?? '',
    );
  }

  Future<void> setAvatarFromFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final directory = await getApplicationDocumentsDirectory();
    final targetPath =
        '${directory.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await sourceFile.copy(targetPath);

    final oldPath = _avatarPath;
    _avatarPath = targetPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, targetPath);

    if (oldPath != null &&
        oldPath != targetPath &&
        !oldPath.contains('avatar_cloud_')) {
      final oldFile = File(oldPath);
      if (await oldFile.exists()) await oldFile.delete();
    }

    notifyListeners();

    // 上传到云端，同时更新 CloudDB 里的 avatarPath 记录
    try {
      final user = await AGCAuth.instance.currentUser;
      final uid = user?.uid;
      if (uid == null) return;

      await AvatarStorageService.instance.uploadAvatar(uid, targetPath);
      await _profileService.saveProfile(
        nickname: _nickname,
        avatarPath: targetPath,
      );
      notifyListeners();
    } catch (e) {
      _uploadError = e.toString();
      notifyListeners();
    }
  }

  String? _uploadError;
  String? get uploadError => _uploadError;
}
