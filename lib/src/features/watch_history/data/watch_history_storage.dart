import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'watch_history_models.dart';

final watchHistoryStorageProvider = Provider<WatchHistoryStorage>((ref) {
  return WatchHistoryStorage();
});

class WatchHistoryStorage {
  static const String _boxName = 'watch_history';

  Box<dynamic>? _box;

  final Map<String, WatchHistory> _pendingWrites = {};
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(seconds: 2);

  Future<void> _ensureBoxOpen() async {
    if (_box == null || !_box!.isOpen) {
      _box = await Hive.openBox(_boxName);
    }
  }

  String _generateKey(String ftpServerId, String contentId) {
    return '${ftpServerId}_$contentId';
  }

  Future<WatchHistory?> getWatchHistory({
    required String ftpServerId,
    required String contentId,
  }) async {
    await _ensureBoxOpen();
    final key = _generateKey(ftpServerId, contentId);
    final data = _box!.get(key);
    if (data == null) {
      return null;
    }

    if (data is Map<String, dynamic>) {
      return WatchHistory.fromJson(data);
    } else if (data is Map) {
      final jsonData = Map<String, dynamic>.from(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
      return WatchHistory.fromJson(jsonData);
    }
    return null;
  }

  Future<void> saveWatchHistory(
    WatchHistory history, {
    bool immediate = false,
  }) async {
    await _ensureBoxOpen();
    final key = _generateKey(history.ftpServerId, history.contentId);

    if (immediate) {
      final jsonData = history.toJson();
      await _box!.put(key, jsonData);
      _pendingWrites.remove(key);
      return;
    }

    _pendingWrites[key] = history;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      _flushPendingWrites();
    });
  }

  Future<void> _flushPendingWrites() async {
    if (_pendingWrites.isEmpty) return;

    await _ensureBoxOpen();

    final writes = <String, Map<String, dynamic>>{};
    for (final entry in _pendingWrites.entries) {
      writes[entry.key] = entry.value.toJson();
    }

    await _box!.putAll(writes);
    _pendingWrites.clear();
  }

  Future<void> deleteWatchHistory({
    required String ftpServerId,
    required String contentId,
  }) async {
    await _ensureBoxOpen();
    final key = _generateKey(ftpServerId, contentId);
    await _box!.delete(key);
  }

  Future<void> deleteAllByStatus(String status) async {
    await _ensureBoxOpen();
    final allData = _box!.values.toList();
    final keysToDelete = <String>[];

    for (var i = 0; i < allData.length; i++) {
      try {
        final data = allData[i];
        final jsonData = data is Map<String, dynamic>
            ? data
            : Map<String, dynamic>.from(
                (data as Map).map((k, v) => MapEntry(k.toString(), v)),
              );
        final history = WatchHistory.fromJson(jsonData);

        if (history.status.value == status) {
          keysToDelete.add(_box!.keyAt(i).toString());
        }
      } catch (_) {}
    }

    for (final key in keysToDelete) {
      await _box!.delete(key);
    }
  }

  Future<List<WatchHistory>> getAllWatchHistories({
    String? status,
    List<String>? workingServerIds,
  }) async {
    await _ensureBoxOpen();
    final allData = _box!.values.toList();

    final histories = allData
        .map((data) {
          try {
            final jsonData = data is Map<String, dynamic>
                ? data
                : Map<String, dynamic>.from(
                    (data as Map).map((k, v) => MapEntry(k.toString(), v)),
                  );
            return WatchHistory.fromJson(jsonData);
          } catch (_) {
            return null;
          }
        })
        .whereType<WatchHistory>()
        .toList();

    var filtered = histories;

    if (status != null && status.isNotEmpty) {
      final targetStatus = WatchStatus.fromString(status);
      filtered = filtered.where((h) => h.status == targetStatus).toList();
    }

    if (workingServerIds != null && workingServerIds.isNotEmpty) {
      filtered = filtered
          .where((h) => workingServerIds.contains(h.ftpServerId))
          .toList();
    }

    filtered.sort((a, b) => b.lastWatchedAt.compareTo(a.lastWatchedAt));

    return filtered;
  }

  Future<void> clearAll() async {
    await _ensureBoxOpen();
    await _box!.clear();
  }

  Future<void> flush() async {
    _debounceTimer?.cancel();
    await _flushPendingWrites();
  }

  void dispose() {
    _debounceTimer?.cancel();
    _pendingWrites.clear();
  }
}
