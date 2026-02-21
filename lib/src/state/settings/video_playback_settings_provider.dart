import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final videoPlaybackSettingsStorageProvider =
    Provider<VideoPlaybackSettingsStorage>((ref) {
      return VideoPlaybackSettingsStorage(const FlutterSecureStorage());
    });

final videoPlaybackSettingsProvider =
    StateNotifierProvider<VideoPlaybackSettingsNotifier, VideoPlaybackSettings>(
      (ref) {
        final storage = ref.watch(videoPlaybackSettingsStorageProvider);
        return VideoPlaybackSettingsNotifier(storage);
      },
    );

class VideoPlaybackSettings {
  const VideoPlaybackSettings({
    required this.holdToSpeedRate,
    required this.autoCompleteThreshold,
    required this.leftDoubleTapSkipSeconds,
    required this.rightDoubleTapSkipSeconds,
  });

  final double holdToSpeedRate;
  final int autoCompleteThreshold;
  final int leftDoubleTapSkipSeconds;
  final int rightDoubleTapSkipSeconds;

  VideoPlaybackSettings copyWith({
    double? holdToSpeedRate,
    int? autoCompleteThreshold,
    int? leftDoubleTapSkipSeconds,
    int? rightDoubleTapSkipSeconds,
  }) {
    return VideoPlaybackSettings(
      holdToSpeedRate: holdToSpeedRate ?? this.holdToSpeedRate,
      autoCompleteThreshold:
          autoCompleteThreshold ?? this.autoCompleteThreshold,
      leftDoubleTapSkipSeconds:
          leftDoubleTapSkipSeconds ?? this.leftDoubleTapSkipSeconds,
      rightDoubleTapSkipSeconds:
          rightDoubleTapSkipSeconds ?? this.rightDoubleTapSkipSeconds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'holdToSpeedRate': holdToSpeedRate,
      'autoCompleteThreshold': autoCompleteThreshold,
      'leftDoubleTapSkipSeconds': leftDoubleTapSkipSeconds,
      'rightDoubleTapSkipSeconds': rightDoubleTapSkipSeconds,
    };
  }

  factory VideoPlaybackSettings.fromJson(Map<String, dynamic> json) {
    return VideoPlaybackSettings(
      holdToSpeedRate: (json['holdToSpeedRate'] as num?)?.toDouble() ?? 2.0,
      autoCompleteThreshold:
          (json['autoCompleteThreshold'] as num?)?.toInt() ?? 90,
      leftDoubleTapSkipSeconds:
          (json['leftDoubleTapSkipSeconds'] as num?)?.toInt() ?? 10,
      rightDoubleTapSkipSeconds:
          (json['rightDoubleTapSkipSeconds'] as num?)?.toInt() ?? 10,
    );
  }

  static const VideoPlaybackSettings defaults = VideoPlaybackSettings(
    holdToSpeedRate: 2.0,
    autoCompleteThreshold: 90,
    leftDoubleTapSkipSeconds: 10,
    rightDoubleTapSkipSeconds: 10,
  );
}

class VideoPlaybackSettingsStorage {
  const VideoPlaybackSettingsStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'video_playback_settings';

  AndroidOptions get _androidOptions =>
      const AndroidOptions(resetOnError: true);
  IOSOptions get _iosOptions =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  Future<VideoPlaybackSettings> load() async {
    try {
      final raw = await _storage.read(
        key: _key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      if (raw == null || raw.isEmpty) return VideoPlaybackSettings.defaults;
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      return VideoPlaybackSettings.fromJson(jsonMap);
    } catch (_) {
      return VideoPlaybackSettings.defaults;
    }
  }

  Future<void> save(VideoPlaybackSettings settings) async {
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

class VideoPlaybackSettingsNotifier
    extends StateNotifier<VideoPlaybackSettings> {
  VideoPlaybackSettingsNotifier(this._storage)
    : super(VideoPlaybackSettings.defaults) {
    _loadSettings();
  }

  final VideoPlaybackSettingsStorage _storage;

  Future<void> _loadSettings() async {
    final loaded = await _storage.load();
    state = loaded;
  }

  Future<void> updateSettings(VideoPlaybackSettings settings) async {
    state = settings;
    await _storage.save(settings);
  }

  Future<void> updateHoldToSpeedRate(double rate) async {
    final newSettings = state.copyWith(holdToSpeedRate: rate);
    state = newSettings;
    await _storage.save(newSettings);
  }

  Future<void> updateAutoCompleteThreshold(int threshold) async {
    final newSettings = state.copyWith(autoCompleteThreshold: threshold);
    state = newSettings;
    await _storage.save(newSettings);
  }

  Future<void> updateLeftDoubleTapSkipSeconds(int seconds) async {
    final newSettings = state.copyWith(leftDoubleTapSkipSeconds: seconds);
    state = newSettings;
    await _storage.save(newSettings);
  }

  Future<void> updateRightDoubleTapSkipSeconds(int seconds) async {
    final newSettings = state.copyWith(rightDoubleTapSkipSeconds: seconds);
    state = newSettings;
    await _storage.save(newSettings);
  }
}
