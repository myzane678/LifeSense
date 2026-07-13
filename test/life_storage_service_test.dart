import 'package:flutter_test/flutter_test.dart';
import 'package:life_sense/models/life_entry.dart';
import 'package:life_sense/services/life_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRemoteStore implements LifeEntryRemoteStore {
  _FakeRemoteStore({this.failWrites = false});

  bool failWrites;
  final Map<String, LifeEntry> entries = {};

  @override
  Future<void> delete(String uid, String entryId) async {
    if (failWrites) throw StateError('offline');
    entries.remove(entryId);
  }

  @override
  Future<List<LifeEntry>> load(String uid) async => entries.values.toList();

  @override
  Future<void> upsert(String uid, LifeEntry entry) async {
    if (failWrites) throw StateError('offline');
    entries[entry.id] = entry;
  }
}

LifeEntry _entry(String id, {int mood = 3}) => LifeEntry(
  id: id,
  createdAt: DateTime(2026, 7, 13, 20),
  mood: mood,
  energy: 3,
  stress: 3,
  focus: 3,
  sleepHours: 7,
  waterCups: 6,
  activity: '学习',
  note: '',
  score: 70,
  status: '状态普通',
  suggestion: '保持节奏',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('离线新增会保留本机记录和待同步操作', () async {
    final remote = _FakeRemoteStore(failWrites: true);
    final service = LifeStorageService(
      remoteStore: remote,
      userIdLoader: () async => 'user-a',
    );

    final synced = await service.saveEntry(_entry('entry-1'));

    expect(synced, isFalse);
    expect(service.pendingSyncCount, 1);
    expect(await service.loadLocalEntriesForTesting('user-a'), hasLength(1));
  });

  test('重试会将持久化的最终修改同步到云端', () async {
    final remote = _FakeRemoteStore(failWrites: true);
    final service = LifeStorageService(
      remoteStore: remote,
      userIdLoader: () async => 'user-a',
    );
    await service.saveEntry(_entry('entry-1', mood: 2));
    await service.saveEntry(_entry('entry-1', mood: 5));

    remote.failWrites = false;
    final synced = await service.retryPendingSync();

    expect(synced, 1);
    expect(service.pendingSyncCount, 0);
    expect(remote.entries['entry-1']?.mood, 5);
  });

  test('离线删除会用 tombstone 阻止旧记录在重试后复活', () async {
    final remote = _FakeRemoteStore()..entries['entry-1'] = _entry('entry-1');
    final service = LifeStorageService(
      remoteStore: remote,
      userIdLoader: () async => 'user-a',
    );
    await service.loadEntries();
    remote.failWrites = true;

    final synced = await service.deleteEntry(_entry('entry-1'));

    expect(synced, isFalse);
    expect(service.pendingSyncCount, 1);
    remote.failWrites = false;
    await service.retryPendingSync();

    expect(remote.entries, isEmpty);
    expect(service.pendingSyncCount, 0);
  });
}
