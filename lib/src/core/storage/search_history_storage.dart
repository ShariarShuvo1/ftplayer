import 'package:hive_flutter/hive_flutter.dart';

class SearchHistoryStorage {
  static const String _boxName = 'search_history';
  static const String _historyKey = 'search_keywords';
  static const int _maxHistorySize = 5;

  Box<dynamic>? _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<void> addSearchKeyword(String keyword) async {
    if (_box == null) await init();

    final trimmedKeyword = keyword.trim();
    if (trimmedKeyword.isEmpty) return;

    List<String> history = getSearchHistory();

    history.remove(trimmedKeyword);

    history.insert(0, trimmedKeyword);

    if (history.length > _maxHistorySize) {
      history = history.sublist(0, _maxHistorySize);
    }

    await _box!.put(_historyKey, history);
  }

  List<String> getSearchHistory() {
    if (_box == null) return [];

    final dynamic storedHistory = _box!.get(_historyKey);
    if (storedHistory == null) return [];

    if (storedHistory is List) {
      return storedHistory.map((e) => e.toString()).toList();
    }

    return [];
  }

  Future<void> clearHistory() async {
    if (_box == null) await init();
    await _box!.delete(_historyKey);
  }

  List<String> getMatchingHistory(String query) {
    if (query.trim().isEmpty) return [];

    final history = getSearchHistory();
    final lowerQuery = query.toLowerCase();

    return history
        .where((keyword) => keyword.toLowerCase().contains(lowerQuery))
        .toList();
  }
}
