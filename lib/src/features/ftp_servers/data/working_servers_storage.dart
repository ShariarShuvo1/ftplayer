import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final workingServersStorageProvider = Provider<WorkingServersStorage>((ref) {
  return WorkingServersStorage();
});

class WorkingServersStorage {
  static const String _boxName = 'working_servers';
  static const String _key = 'working_server_ids';

  Box<dynamic>? _box;

  Future<void> _ensureBoxOpen() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
  }

  Future<List<String>> getWorkingServerIds() async {
    await _ensureBoxOpen();
    final stored = _box!.get(_key);
    if (stored == null) {
      return [];
    }
    if (stored is List) {
      return stored.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> saveWorkingServerIds(List<String> serverIds) async {
    await _ensureBoxOpen();
    await _box!.put(_key, serverIds);
  }

  Future<void> clearWorkingServerIds() async {
    await _ensureBoxOpen();
    await _box!.delete(_key);
  }

  Future<void> addWorkingServerId(String serverId) async {
    final currentIds = await getWorkingServerIds();
    if (!currentIds.contains(serverId)) {
      currentIds.add(serverId);
      await saveWorkingServerIds(currentIds);
    }
  }

  Future<void> removeWorkingServerId(String serverId) async {
    final currentIds = await getWorkingServerIds();
    currentIds.remove(serverId);
    await saveWorkingServerIds(currentIds);
  }
}
