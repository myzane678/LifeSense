import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/digest_preferences_service.dart';
import '../services/reminder_service.dart';
import '../services/platform_capabilities.dart';
import '../services/user_settings_service.dart';
import '../services/weekly_goals_service.dart';
import '../state/life_entry_provider.dart';
import '../state/profile_provider.dart';
import '../widgets/digest_interest_dialog.dart';

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
    final isGuest = context.read<LifeEntryProvider>().isGuestMode;
    try {
      await profile.setNickname(nickname);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isGuest ? '昵称已保存在本机' : '昵称已保存并同步')),
      );
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
            if (!isWindowsLocalMode)
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('头像上传失败：$error')));
      }
    } catch (_) {}
  }

  Future<void> editDigestInterests(BuildContext context) async {
    final preferences = context.read<DigestPreferencesService>();
    final selected = await showDigestInterestDialog(
      context,
      initialIds: preferences.selectedIds,
      title: '兴趣方向',
      description: '选择 1-3 个方向，用于个性化每日速览内容。',
    );
    if (selected == null || !context.mounted) return;
    try {
      await preferences.setSelectedIds(selected);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isWindowsLocalMode ? '兴趣方向已保存到本机' : '兴趣方向已更新并同步到云端'),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('已保存到本机，云同步失败'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () async {
              try {
                await preferences.retryPendingSync();
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('兴趣方向已同步到云端')));
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('云同步仍未成功，请稍后重试')));
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> toggleReminder(BuildContext context, bool enabled) async {
    final reminder = context.read<ReminderService>();
    if (!enabled) {
      await reminder.disableDailyReminder();
      return;
    }
    final granted = await reminder.enableDailyReminder();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(granted ? '每日提醒已开启' : '未获得通知权限，可稍后在系统设置中开启')),
    );
  }

  Future<void> chooseReminderTime(BuildContext context) async {
    final reminder = context.read<ReminderService>();
    final picked = await showTimePicker(
      context: context,
      initialTime: reminder.reminderTime,
    );
    if (picked == null || !context.mounted) return;
    await reminder.setReminderTime(picked);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('提醒时间已更新')));
  }

  Future<void> retryEntrySync(BuildContext context) async {
    final synced = await context.read<LifeEntryProvider>().retryPendingSync();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(synced > 0 ? '已同步 $synced 项本机修改' : '仍有待同步记录，请稍后重试'),
      ),
    );
  }

  Future<void> recalculateEntries(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重新计算历史分数'),
        content: const Text('将按最新算法重新计算所有历史记录的分数、状态和建议，并同步保存。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context.read<LifeEntryProvider>().recalculateAllEntries();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('历史分数已重新计算并保存')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('重新计算失败，请稍后再试')));
    }
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
        title: const Text('删除云端数据'),
        content: const Text('这会删除当前账号云端和本机的全部历史记录与设置，删除后无法恢复。'),
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
    try {
      final uid = context.read<AuthService>().currentUser?.uid;
      if (uid == null) return;
      await UserSettingsService.instance.deleteForUser(uid);
      if (!context.mounted) return;
      await context.read<LifeEntryProvider>().deleteCloudEntries();
      if (!context.mounted) return;
      await context.read<DigestPreferencesService>().clearForUser(uid);
      if (!context.mounted) return;
      await context.read<WeeklyGoalsService>().clearForUser(uid);
      if (context.mounted) Navigator.pop(context);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('云端删除失败，请稍后重试')));
    }
  }

  Future<void> signOut(BuildContext context) async {
    await context.read<AuthService>().signOut();
    if (!context.mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> exitGuestMode(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出访客模式'),
        content: const Text('退出后将回到登录页。本机记录不会被删除，但注册账号后无法自动迁移。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthService>().exitGuestMode();
    if (!context.mounted) return;
    context.read<LifeEntryProvider>().setGuestMode(false);
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _clearGuestEntries(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空本机记录'),
        content: const Text('将删除所有访客记录，且无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<LifeEntryProvider>().clearGuestEntries();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('本机访客记录已清空')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LifeEntryProvider>();
    final profile = context.watch<ProfileProvider>();
    final reminder = context.watch<ReminderService>();
    final digestPreferences = context.watch<DigestPreferencesService>();
    final isWindows = isWindowsLocalMode;
    final isGuest = provider.isGuestMode;
    final colorScheme = Theme.of(context).colorScheme;
    final email = isGuest
        ? ''
        : (context.read<AuthService>().currentUser?.email ?? '');
    final syncText = switch (provider.syncStatus) {
      SyncStatus.synced => '已同步到云端',
      SyncStatus.localCache =>
        provider.hasPendingSync
            ? '有 ${provider.pendingSyncCount} 项待同步'
            : '当前显示本机缓存',
      SyncStatus.syncing => '正在同步',
      SyncStatus.localOnly => '访客模式 · 数据仅存本机',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ProfileCard(
            profile: profile,
            isGuest: isGuest,
            onEditNickname: () => editNickname(context),
            onChooseAvatar: () => chooseAvatar(context),
          ),
          const SizedBox(height: 16),
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
                          isGuest ? '访客' : email,
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
          if (isWindows)
            Card(
              elevation: 0,
              color: colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Windows 本地模式：记录、头像、兴趣和目标仅保存在此电脑；暂不支持登录、云同步、拍照和后台每日提醒。',
                  style: TextStyle(color: colorScheme.onSecondaryContainer),
                ),
              ),
            ),
          if (isWindows) const SizedBox(height: 16),
          _SectionLabel('每日速览'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLow,
            child: ListTile(
              leading: const Icon(Icons.tune_outlined),
              title: const Text('兴趣方向'),
              subtitle: Text(digestPreferences.selectedLabelText),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => editDigestInterests(context),
            ),
          ),
          const SizedBox(height: 16),
          if (isWindows) ...[
            _SectionLabel('日常提醒'),
            const Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(Icons.notifications_off_outlined),
                title: Text('后台每日提醒暂不支持'),
                subtitle: Text('Windows 本地版暂不提供后台通知。'),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            _SectionLabel('日常提醒'),
            _ReminderCard(
              reminder: reminder,
              onToggle: (enabled) => toggleReminder(context, enabled),
              onChooseTime: () => chooseReminderTime(context),
            ),
            const SizedBox(height: 16),
          ],

          if (isGuest || isWindows) ...[
            if (!isWindows) ...[
              Card(
                elevation: 0,
                color: colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_upload_outlined,
                            color: colorScheme.secondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '开启云同步',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '注册账号后，记录自动同步到云端，换机或重装后随时恢复。',
                        style: TextStyle(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => exitGuestMode(context),
                        child: const Text('注册 / 登录账号'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _SectionLabel('数据管理'),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: ListTile(
                leading: Icon(Icons.delete_outline, color: colorScheme.error),
                title: Text(
                  '清空本机记录',
                  style: TextStyle(color: colorScheme.error),
                ),
                subtitle: const Text('删除本机全部访客记录，不可恢复'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _clearGuestEntries(context),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: ListTile(
                leading: const Icon(Icons.calculate_outlined),
                title: const Text('重新计算历史分数'),
                subtitle: const Text('按最新算法更新所有记录的分数和建议'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => recalculateEntries(context),
              ),
            ),
            const SizedBox(height: 16),
            if (!isWindows) ...[
              _SectionLabel('账号'),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerLow,
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('退出访客模式'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => exitGuestMode(context),
                ),
              ),
            ],
          ] else ...[
            _SectionLabel('数据管理'),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLow,
              child: Column(
                children: [
                  if (provider.hasPendingSync)
                    ListTile(
                      title: Text('有 ${provider.pendingSyncCount} 项待同步'),
                      trailing: const Icon(Icons.sync),
                      onTap: () => retryEntrySync(context),
                    ),
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
                  const Divider(indent: 56, height: 0),
                  ListTile(
                    leading: const Icon(Icons.calculate_outlined),
                    title: const Text('重新计算历史分数'),
                    subtitle: const Text('按最新算法更新所有记录的分数和建议'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => recalculateEntries(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.onToggle,
    required this.onChooseTime,
  });

  final ReminderService reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onChooseTime;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('每日记录提醒'),
            subtitle: Text(
              reminder.schedulePending
                  ? '提醒尚未安排，点此重试'
                  : reminder.enabled
                  ? '每天 ${reminder.reminderTimeText} 提醒'
                  : '已关闭',
            ),
            value: reminder.enabled,
            onChanged: reminder.isInitialized ? onToggle : null,
          ),
          if (reminder.schedulePending) ...[
            const Divider(indent: 56, height: 0),
            ListTile(
              leading: const Icon(Icons.refresh_outlined),
              title: const Text('重试安排提醒'),
              onTap: reminder.retrySchedule,
            ),
          ],
          if (reminder.enabled) ...[
            const Divider(indent: 56, height: 0),
            ListTile(
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('提醒时间'),
              subtitle: Text(reminder.reminderTimeText),
              trailing: const Icon(Icons.chevron_right),
              onTap: onChooseTime,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isGuest,
    required this.onEditNickname,
    required this.onChooseAvatar,
  });

  final ProfileProvider profile;
  final bool isGuest;
  final VoidCallback onEditNickname;
  final VoidCallback onChooseAvatar;

  String _profileSubtitle() {
    if (isGuest) return '访客模式，头像和昵称仅存本机';
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
