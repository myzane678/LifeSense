import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/life_entry_provider.dart';
import '../state/profile_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> editNickname(BuildContext context) async {
    final profile = context.read<ProfileProvider>();
    final controller = TextEditingController(text: profile.nickname);
    final nickname = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置昵称'),
        content: TextField(
          controller: controller,
          maxLength: 16,
          decoration: const InputDecoration(hintText: '输入你的昵称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (nickname == null || !context.mounted) return;
    try {
      await profile.setNickname(nickname);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('昵称已保存并同步')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('昵称已保存在本机，云同步稍后再试')));
    }
  }

  Future<void> chooseAvatar(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              subtitle: const Text('将打开系统相册选择图片'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              subtitle: const Text('需要同意使用相机权限'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (image == null || !context.mounted) return;
    try {
      await context.read<ProfileProvider>().setAvatarFromFile(image.path);
      if (!context.mounted) return;
      final error = context.read<ProfileProvider>().uploadError;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像上传失败：$error')),
        );
      }
    } catch (_) {}
  }

  Future<void> clearLocalCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空本机缓存'),
        content: const Text('这只会清除当前手机上的缓存记录，不会删除云端历史。重新登录或同步后，云端记录仍可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空本机'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final cleared = await context.read<LifeEntryProvider>().clearLocalCache();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cleared ? '本机缓存已清空' : '云端没有可恢复记录，已保留本机缓存')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('云端检查失败，已保留本机缓存')));
    }
  }

  Future<void> restoreFromCloud(BuildContext context) async {
    try {
      final restored = await context
          .read<LifeEntryProvider>()
          .restoreFromCloud();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(restored ? '已从云端恢复历史记录' : '云端暂无可恢复记录')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('云端恢复失败，请稍后再试')));
    }
  }

  Future<void> deleteCloudEntries(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除云端历史记录'),
        content: const Text('这会删除当前账号云端和本机的全部 LifeSense 记录，删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<LifeEntryProvider>().deleteCloudEntries();
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> signOut(BuildContext context) async {
    await context.read<AuthService>().signOut();
    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final email = context.read<AuthService>().currentUser?.email ?? '';
    final provider = context.watch<LifeEntryProvider>();
    final profile = context.watch<ProfileProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final syncText = switch (provider.syncStatus) {
      SyncStatus.synced => '已同步到云端',
      SyncStatus.localCache => '当前显示本机缓存',
      SyncStatus.syncing => '正在同步',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ProfileCard(
            profile: profile,
            onEditNickname: () => editNickname(context),
            onChooseAvatar: () => chooseAvatar(context),
          ),
          const SizedBox(height: 16),
          // 账号信息卡
          Card(
            elevation: 0,
            color: colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary,
                    child: Icon(
                      Icons.person_outline,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          email,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          syncText,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onPrimaryContainer.withAlpha(
                              180,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 数据管理
          _SectionLabel('数据管理'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.phone_android_outlined),
                  title: const Text('清空本机缓存'),
                  subtitle: const Text('确认云端可恢复后再清除此手机缓存'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => clearLocalCache(context),
                ),
                const Divider(indent: 56, height: 0),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('从云端恢复历史记录'),
                  subtitle: const Text('重新读取当前账号的云端记录'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => restoreFromCloud(context),
                ),
                const Divider(indent: 56, height: 0),
                ListTile(
                  leading: Icon(
                    Icons.cloud_off_outlined,
                    color: colorScheme.error,
                  ),
                  title: Text(
                    '删除云端历史记录',
                    style: TextStyle(color: colorScheme.error),
                  ),
                  subtitle: const Text('删除当前账号云端和本机记录'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => deleteCloudEntries(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 账号操作
          _SectionLabel('账号'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('退出登录'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => signOut(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.onEditNickname,
    required this.onChooseAvatar,
  });

  final ProfileProvider profile;
  final VoidCallback onEditNickname;
  final VoidCallback onChooseAvatar;

  String _profileSubtitle() {
    final hasNickname = profile.hasNickname;
    final hasAvatar = profile.avatarPath != null;
    if (hasNickname && hasAvatar) return '头像和昵称已同步云端';
    if (hasNickname) return '昵称已同步云端 · 未设置头像';
    if (hasAvatar) return '头像已同步云端 · 未设置昵称';
    return '点击设置头像和昵称';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final avatarPath = profile.avatarPath;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: onChooseAvatar,
              child: CircleAvatar(
                radius: 32,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: avatarPath == null
                    ? null
                    : FileImage(File(avatarPath)),
                child: avatarPath == null
                    ? Icon(
                        Icons.add_a_photo_outlined,
                        color: colorScheme.primary,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.hasNickname ? profile.nickname : '未设置昵称',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _profileSubtitle(),
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEditNickname,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
