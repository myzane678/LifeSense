import 'dart:io';

import 'package:agconnect_cloudstorage/agconnect_cloudstorage.dart';

class AvatarStorageService {
  AvatarStorageService._();
  static final AvatarStorageService instance = AvatarStorageService._();

  AGCStorage get _storage => AGCStorage.getInstance();

  String _cloudPath(String uid) => 'avatars/$uid.jpg';

  Future<String> uploadAvatar(String uid, String localPath) async {
    final ref = _storage.reference(_cloudPath(uid));
    final task = await ref.uploadFile(File(localPath));
    while (!task.isComplete) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!task.isSuccessful) throw Exception('头像上传失败');
    return await ref.getDownloadUrl();
  }

  Future<void> downloadAvatar(String uid, String localPath) async {
    final ref = _storage.reference(_cloudPath(uid));
    final dest = File(localPath);
    if (!await dest.parent.exists()) {
      await dest.parent.create(recursive: true);
    }
    final task = await ref.downloadToFile(dest);
    while (!task.isComplete) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (!task.isSuccessful) throw Exception('头像下载失败');
  }

  Future<void> deleteAvatar(String uid) async {
    try {
      await _storage.reference(_cloudPath(uid)).deleteFile();
    } catch (_) {}
  }
}
