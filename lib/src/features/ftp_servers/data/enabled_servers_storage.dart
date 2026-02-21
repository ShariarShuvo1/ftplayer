import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final enabledServersStorageProvider = Provider<EnabledServersStorage>((ref) {
  return EnabledServersStorage();
});

class EnabledServersStorage {
  static const String _boxName = 'enabled_servers';
  static const String _key = 'enabled_server_ids';

  Box<dynamic>? _box;

  Future<void> _ensureBoxOpen() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
  }

  Future<List<String>> getEnabledServerIds() async {
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

  Future<void> saveEnabledServerIds(List<String> serverIds) async {
    await _ensureBoxOpen();
    await _box!.put(_key, serverIds);
  }

  Future<void> enableServer(String serverId) async {
    final currentIds = await getEnabledServerIds();
    if (!currentIds.contains(serverId)) {
      currentIds.add(serverId);
      await saveEnabledServerIds(currentIds);
    }
  }

  Future<void> disableServer(String serverId) async {
    final currentIds = await getEnabledServerIds();
    currentIds.remove(serverId);
    await saveEnabledServerIds(currentIds);
  }

  Future<void> clearEnabledServers() async {
    await _ensureBoxOpen();
    await _box!.delete(_key);
  }
}
