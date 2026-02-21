import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final homeContentSettingsStorageProvider = Provider<HomeContentSettingsStorage>(
  (ref) {
    return HomeContentSettingsStorage(const FlutterSecureStorage());
  },
);

final homeContentSettingsProvider =
    StateNotifierProvider<HomeContentSettingsNotifier, HomeContentSettings>((
      ref,
    ) {
      final storage = ref.watch(homeContentSettingsStorageProvider);
      return HomeContentSettingsNotifier(storage);
    });

class HomeContentSettings {
  const HomeContentSettings({
    required this.featuredCircleFtp,
    required this.featuredAmaderFtp,
    required this.featuredDflix,
    required this.trendingCircleFtp,
    required this.trendingAmaderFtp,
    required this.trendingDflix,
    required this.latestCircleFtp,
    required this.latestAmaderFtp,
    required this.latestDflix,
    required this.tvSeriesCircleFtp,
    required this.tvSeriesAmaderFtp,
    required this.tvSeriesDflix,
    required this.pingTimeCircleFtp,
    required this.pingTimeAmaderFtp,
    required this.pingTimeDflix,
  });

  final int featuredCircleFtp;
  final int featuredAmaderFtp;
  final int featuredDflix;
  final int trendingCircleFtp;
  final int trendingAmaderFtp;
  final int trendingDflix;
  final int latestCircleFtp;
  final int latestAmaderFtp;
  final int latestDflix;
  final int tvSeriesCircleFtp;
  final int tvSeriesAmaderFtp;
  final int tvSeriesDflix;
  final int pingTimeCircleFtp;
  final int pingTimeAmaderFtp;
  final int pingTimeDflix;

  int getTotalFeatured(List<String> workingServerTypes) {
    int total = 0;
    if (workingServerTypes.contains('circleftp')) total += featuredCircleFtp;
    if (workingServerTypes.contains('amaderftp')) total += featuredAmaderFtp;
    if (workingServerTypes.contains('dflix')) total += featuredDflix;
    return total;
  }

  int getTotalTrending(List<String> workingServerTypes) {
    int total = 0;
    if (workingServerTypes.contains('circleftp')) total += trendingCircleFtp;
    if (workingServerTypes.contains('amaderftp')) total += trendingAmaderFtp;
    if (workingServerTypes.contains('dflix')) total += trendingDflix;
    return total;
  }

  int getTotalLatest(List<String> workingServerTypes) {
    int total = 0;
    if (workingServerTypes.contains('circleftp')) total += latestCircleFtp;
    if (workingServerTypes.contains('amaderftp')) total += latestAmaderFtp;
    if (workingServerTypes.contains('dflix')) total += latestDflix;
    return total;
  }

  int getTotalTvSeries(List<String> workingServerTypes) {
    int total = 0;
    if (workingServerTypes.contains('circleftp')) total += tvSeriesCircleFtp;
    if (workingServerTypes.contains('amaderftp')) total += tvSeriesAmaderFtp;
    if (workingServerTypes.contains('dflix')) total += tvSeriesDflix;
    return total;
  }

  HomeContentSettings copyWith({
    int? featuredCircleFtp,
    int? featuredAmaderFtp,
    int? featuredDflix,
    int? trendingCircleFtp,
    int? trendingAmaderFtp,
    int? trendingDflix,
    int? latestCircleFtp,
    int? latestAmaderFtp,
    int? latestDflix,
    int? tvSeriesCircleFtp,
    int? tvSeriesAmaderFtp,
    int? tvSeriesDflix,
    int? pingTimeCircleFtp,
    int? pingTimeAmaderFtp,
    int? pingTimeDflix,
  }) {
    return HomeContentSettings(
      featuredCircleFtp: featuredCircleFtp ?? this.featuredCircleFtp,
      featuredAmaderFtp: featuredAmaderFtp ?? this.featuredAmaderFtp,
      featuredDflix: featuredDflix ?? this.featuredDflix,
      trendingCircleFtp: trendingCircleFtp ?? this.trendingCircleFtp,
      trendingAmaderFtp: trendingAmaderFtp ?? this.trendingAmaderFtp,
      trendingDflix: trendingDflix ?? this.trendingDflix,
      latestCircleFtp: latestCircleFtp ?? this.latestCircleFtp,
      latestAmaderFtp: latestAmaderFtp ?? this.latestAmaderFtp,
      latestDflix: latestDflix ?? this.latestDflix,
      tvSeriesCircleFtp: tvSeriesCircleFtp ?? this.tvSeriesCircleFtp,
      tvSeriesAmaderFtp: tvSeriesAmaderFtp ?? this.tvSeriesAmaderFtp,
      tvSeriesDflix: tvSeriesDflix ?? this.tvSeriesDflix,
      pingTimeCircleFtp: pingTimeCircleFtp ?? this.pingTimeCircleFtp,
      pingTimeAmaderFtp: pingTimeAmaderFtp ?? this.pingTimeAmaderFtp,
      pingTimeDflix: pingTimeDflix ?? this.pingTimeDflix,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'featuredCircleFtp': featuredCircleFtp,
      'featuredAmaderFtp': featuredAmaderFtp,
      'featuredDflix': featuredDflix,
      'trendingCircleFtp': trendingCircleFtp,
      'trendingAmaderFtp': trendingAmaderFtp,
      'trendingDflix': trendingDflix,
      'latestCircleFtp': latestCircleFtp,
      'latestAmaderFtp': latestAmaderFtp,
      'latestDflix': latestDflix,
      'tvSeriesCircleFtp': tvSeriesCircleFtp,
      'tvSeriesAmaderFtp': tvSeriesAmaderFtp,
      'tvSeriesDflix': tvSeriesDflix,
      'pingTimeCircleFtp': pingTimeCircleFtp,
      'pingTimeAmaderFtp': pingTimeAmaderFtp,
      'pingTimeDflix': pingTimeDflix,
    };
  }

  factory HomeContentSettings.fromJson(Map<String, dynamic> json) {
    return HomeContentSettings(
      featuredCircleFtp: json['featuredCircleFtp'] as int? ?? 5,
      featuredAmaderFtp: json['featuredAmaderFtp'] as int? ?? 5,
      featuredDflix: json['featuredDflix'] as int? ?? 5,
      trendingCircleFtp: json['trendingCircleFtp'] as int? ?? 10,
      trendingAmaderFtp: json['trendingAmaderFtp'] as int? ?? 10,
      trendingDflix: json['trendingDflix'] as int? ?? 10,
      latestCircleFtp: json['latestCircleFtp'] as int? ?? 10,
      latestAmaderFtp: json['latestAmaderFtp'] as int? ?? 10,
      latestDflix: json['latestDflix'] as int? ?? 10,
      tvSeriesCircleFtp: json['tvSeriesCircleFtp'] as int? ?? 10,
      tvSeriesAmaderFtp: json['tvSeriesAmaderFtp'] as int? ?? 10,
      tvSeriesDflix: json['tvSeriesDflix'] as int? ?? 10,
      pingTimeCircleFtp: json['pingTimeCircleFtp'] as int? ?? 3,
      pingTimeAmaderFtp: json['pingTimeAmaderFtp'] as int? ?? 3,
      pingTimeDflix: json['pingTimeDflix'] as int? ?? 3,
    );
  }

  static const HomeContentSettings defaults = HomeContentSettings(
    featuredCircleFtp: 5,
    featuredAmaderFtp: 5,
    featuredDflix: 5,
    trendingCircleFtp: 10,
    trendingAmaderFtp: 10,
    trendingDflix: 10,
    latestCircleFtp: 10,
    latestAmaderFtp: 10,
    latestDflix: 10,
    tvSeriesCircleFtp: 10,
    tvSeriesAmaderFtp: 10,
    tvSeriesDflix: 10,
    pingTimeCircleFtp: 3,
    pingTimeAmaderFtp: 3,
    pingTimeDflix: 3,
  );
}

class HomeContentSettingsStorage {
  const HomeContentSettingsStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'home_content_settings';

  AndroidOptions get _androidOptions =>
      const AndroidOptions(resetOnError: true);
  IOSOptions get _iosOptions =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  Future<HomeContentSettings> load() async {
    try {
      final raw = await _storage.read(
        key: _key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      if (raw == null || raw.isEmpty) return HomeContentSettings.defaults;
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      return HomeContentSettings.fromJson(jsonMap);
    } catch (_) {
      return HomeContentSettings.defaults;
    }
  }

  Future<void> save(HomeContentSettings settings) async {
    try {
      final encoded = jsonEncode(settings.toJson());
      await _storage.write(
        key: _key,
        value: encoded,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } catch (_) {}
  }
}

class HomeContentSettingsNotifier extends StateNotifier<HomeContentSettings> {
  HomeContentSettingsNotifier(this._storage)
    : super(HomeContentSettings.defaults) {
    _loadSettings();
  }

  final HomeContentSettingsStorage _storage;

  Future<void> _loadSettings() async {
    final loaded = await _storage.load();
    state = loaded;
  }

  Future<void> updateSettings(HomeContentSettings settings) async {
    state = settings;
    await _storage.save(settings);
  }
}
