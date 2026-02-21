import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class VibrationSettings {
  final bool enabled;
  final double strength;
  final bool vibrateOnTabChange;
  final bool vibrateOnAppbar;
  final bool vibrateOnMenuNavigation;
  final bool vibrateOnDownloadScreen;
  final bool vibrateOnWatchHistory;
  final bool vibrateOnDownloadButton;
  final bool vibrateOnSeasonSection;
  final bool vibrateOnPip;
  final bool vibrateOnGestures;
  final bool vibrateOnVideoController;
  final bool vibrateOnDoubleTap;
  final bool vibrateOnHoldFastForward;
  final bool vibrateOnBottomSheet;
  final bool vibrateOnContentDetailsOthers;

  const VibrationSettings({
    required this.enabled,
    required this.strength,
    required this.vibrateOnTabChange,
    required this.vibrateOnAppbar,
    required this.vibrateOnMenuNavigation,
    required this.vibrateOnDownloadScreen,
    required this.vibrateOnWatchHistory,
    required this.vibrateOnDownloadButton,
    required this.vibrateOnSeasonSection,
    required this.vibrateOnPip,
    required this.vibrateOnGestures,
    required this.vibrateOnVideoController,
    required this.vibrateOnDoubleTap,
    required this.vibrateOnHoldFastForward,
    required this.vibrateOnBottomSheet,
    required this.vibrateOnContentDetailsOthers,
  });

  VibrationSettings copyWith({
    bool? enabled,
    double? strength,
    bool? vibrateOnTabChange,
    bool? vibrateOnAppbar,
    bool? vibrateOnMenuNavigation,
    bool? vibrateOnDownloadScreen,
    bool? vibrateOnWatchHistory,
    bool? vibrateOnDownloadButton,
    bool? vibrateOnSeasonSection,
    bool? vibrateOnPip,
    bool? vibrateOnGestures,
    bool? vibrateOnVideoController,
    bool? vibrateOnDoubleTap,
    bool? vibrateOnHoldFastForward,
    bool? vibrateOnBottomSheet,
    bool? vibrateOnContentDetailsOthers,
  }) {
    return VibrationSettings(
      enabled: enabled ?? this.enabled,
      strength: strength ?? this.strength,
      vibrateOnTabChange: vibrateOnTabChange ?? this.vibrateOnTabChange,
      vibrateOnAppbar: vibrateOnAppbar ?? this.vibrateOnAppbar,
      vibrateOnMenuNavigation:
          vibrateOnMenuNavigation ?? this.vibrateOnMenuNavigation,
      vibrateOnDownloadScreen:
          vibrateOnDownloadScreen ?? this.vibrateOnDownloadScreen,
      vibrateOnWatchHistory:
          vibrateOnWatchHistory ?? this.vibrateOnWatchHistory,
      vibrateOnDownloadButton:
          vibrateOnDownloadButton ?? this.vibrateOnDownloadButton,
      vibrateOnSeasonSection:
          vibrateOnSeasonSection ?? this.vibrateOnSeasonSection,
      vibrateOnPip: vibrateOnPip ?? this.vibrateOnPip,
      vibrateOnGestures: vibrateOnGestures ?? this.vibrateOnGestures,
      vibrateOnVideoController:
          vibrateOnVideoController ?? this.vibrateOnVideoController,
      vibrateOnDoubleTap: vibrateOnDoubleTap ?? this.vibrateOnDoubleTap,
      vibrateOnHoldFastForward:
          vibrateOnHoldFastForward ?? this.vibrateOnHoldFastForward,
      vibrateOnBottomSheet: vibrateOnBottomSheet ?? this.vibrateOnBottomSheet,
      vibrateOnContentDetailsOthers:
          vibrateOnContentDetailsOthers ?? this.vibrateOnContentDetailsOthers,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'strength': strength,
      'vibrateOnTabChange': vibrateOnTabChange,
      'vibrateOnAppbar': vibrateOnAppbar,
      'vibrateOnMenuNavigation': vibrateOnMenuNavigation,
      'vibrateOnDownloadScreen': vibrateOnDownloadScreen,
      'vibrateOnWatchHistory': vibrateOnWatchHistory,
      'vibrateOnDownloadButton': vibrateOnDownloadButton,
      'vibrateOnSeasonSection': vibrateOnSeasonSection,
      'vibrateOnPip': vibrateOnPip,
      'vibrateOnGestures': vibrateOnGestures,
      'vibrateOnVideoController': vibrateOnVideoController,
      'vibrateOnDoubleTap': vibrateOnDoubleTap,
      'vibrateOnHoldFastForward': vibrateOnHoldFastForward,
      'vibrateOnBottomSheet': vibrateOnBottomSheet,
      'vibrateOnContentDetailsOthers': vibrateOnContentDetailsOthers,
    };
  }

  factory VibrationSettings.fromJson(Map<String, dynamic> json) {
    return VibrationSettings(
      enabled: json['enabled'] as bool? ?? true,
      strength: (json['strength'] as num?)?.toDouble() ?? 0.25,
      vibrateOnTabChange: json['vibrateOnTabChange'] as bool? ?? false,
      vibrateOnAppbar: json['vibrateOnAppbar'] as bool? ?? true,
      vibrateOnMenuNavigation: json['vibrateOnMenuNavigation'] as bool? ?? true,
      vibrateOnDownloadScreen:
          json['vibrateOnDownloadScreen'] as bool? ?? false,
      vibrateOnWatchHistory: json['vibrateOnWatchHistory'] as bool? ?? false,
      vibrateOnDownloadButton: json['vibrateOnDownloadButton'] as bool? ?? true,
      vibrateOnSeasonSection: json['vibrateOnSeasonSection'] as bool? ?? true,
      vibrateOnPip: json['vibrateOnPip'] as bool? ?? false,
      vibrateOnGestures: json['vibrateOnGestures'] as bool? ?? true,
      vibrateOnVideoController:
          json['vibrateOnVideoController'] as bool? ?? false,
      vibrateOnDoubleTap: json['vibrateOnDoubleTap'] as bool? ?? false,
      vibrateOnHoldFastForward:
          json['vibrateOnHoldFastForward'] as bool? ?? true,
      vibrateOnBottomSheet: json['vibrateOnBottomSheet'] as bool? ?? true,
      vibrateOnContentDetailsOthers:
          json['vibrateOnContentDetailsOthers'] as bool? ?? false,
    );
  }
}

class VibrationSettingsNotifier extends Notifier<VibrationSettings> {
  static const String _boxName = 'vibration_settings';
  static const String _settingsKey = 'settings';

  @override
  VibrationSettings build() {
    _loadSettings();
    return const VibrationSettings(
      enabled: true,
      strength: 0.25,
      vibrateOnTabChange: false,
      vibrateOnAppbar: true,
      vibrateOnMenuNavigation: true,
      vibrateOnDownloadScreen: false,
      vibrateOnWatchHistory: false,
      vibrateOnDownloadButton: true,
      vibrateOnSeasonSection: true,
      vibrateOnPip: false,
      vibrateOnGestures: true,
      vibrateOnVideoController: false,
      vibrateOnDoubleTap: false,
      vibrateOnHoldFastForward: true,
      vibrateOnBottomSheet: true,
      vibrateOnContentDetailsOthers: false,
    );
  }

  Future<void> _loadSettings() async {
    final box = await Hive.openBox<String>(_boxName);
    final json = box.get(_settingsKey);
    if (json != null) {
      final data = Map<String, dynamic>.from(
        Uri.splitQueryString(json).map((k, v) => MapEntry(k, _parseValue(v))),
      );
      state = VibrationSettings.fromJson(data);
    }
  }

  dynamic _parseValue(String value) {
    if (value == 'true') return true;
    if (value == 'false') return false;
    final doubleValue = double.tryParse(value);
    if (doubleValue != null) return doubleValue;
    return value;
  }

  Future<void> _saveSettings(VibrationSettings settings) async {
    final box = await Hive.openBox<String>(_boxName);
    final json = settings.toJson();
    final encoded = json.entries.map((e) => '${e.key}=${e.value}').join('&');
    await box.put(_settingsKey, encoded);
  }

  Future<void> updateSettings(VibrationSettings settings) async {
    state = settings;
    await _saveSettings(settings);
  }

  Future<void> toggleEnabled() async {
    final newSettings = state.copyWith(enabled: !state.enabled);
    await updateSettings(newSettings);
  }

  Future<void> updateStrength(double strength) async {
    final newSettings = state.copyWith(strength: strength);
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnTabChange() async {
    final newSettings = state.copyWith(
      vibrateOnTabChange: !state.vibrateOnTabChange,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnAppbar() async {
    final newSettings = state.copyWith(vibrateOnAppbar: !state.vibrateOnAppbar);
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnMenuNavigation() async {
    final newSettings = state.copyWith(
      vibrateOnMenuNavigation: !state.vibrateOnMenuNavigation,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnDownloadScreen() async {
    final newSettings = state.copyWith(
      vibrateOnDownloadScreen: !state.vibrateOnDownloadScreen,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnWatchHistory() async {
    final newSettings = state.copyWith(
      vibrateOnWatchHistory: !state.vibrateOnWatchHistory,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnDownloadButton() async {
    final newSettings = state.copyWith(
      vibrateOnDownloadButton: !state.vibrateOnDownloadButton,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnSeasonSection() async {
    final newSettings = state.copyWith(
      vibrateOnSeasonSection: !state.vibrateOnSeasonSection,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnPip() async {
    final newSettings = state.copyWith(vibrateOnPip: !state.vibrateOnPip);
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnGestures() async {
    final newSettings = state.copyWith(
      vibrateOnGestures: !state.vibrateOnGestures,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnVideoController() async {
    final newSettings = state.copyWith(
      vibrateOnVideoController: !state.vibrateOnVideoController,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnDoubleTap() async {
    final newSettings = state.copyWith(
      vibrateOnDoubleTap: !state.vibrateOnDoubleTap,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnHoldFastForward() async {
    final newSettings = state.copyWith(
      vibrateOnHoldFastForward: !state.vibrateOnHoldFastForward,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnBottomSheet() async {
    final newSettings = state.copyWith(
      vibrateOnBottomSheet: !state.vibrateOnBottomSheet,
    );
    await updateSettings(newSettings);
  }

  Future<void> toggleVibrateOnContentDetailsOthers() async {
    final newSettings = state.copyWith(
      vibrateOnContentDetailsOthers: !state.vibrateOnContentDetailsOthers,
    );
    await updateSettings(newSettings);
  }
}

final vibrationSettingsProvider =
    NotifierProvider<VibrationSettingsNotifier, VibrationSettings>(
      VibrationSettingsNotifier.new,
    );
