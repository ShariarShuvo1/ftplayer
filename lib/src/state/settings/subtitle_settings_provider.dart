import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/config/subtitle_settings.dart';

final subtitleSettingsStorageProvider = Provider<SubtitleSettingsStorage>((
  ref,
) {
  return SubtitleSettingsStorage(const FlutterSecureStorage());
});

final subtitleSettingsProvider =
    StateNotifierProvider<SubtitleSettingsNotifier, SubtitleSettings>((ref) {
      final storage = ref.watch(subtitleSettingsStorageProvider);
      return SubtitleSettingsNotifier(storage);
    });

class SubtitleSettingsNotifier extends StateNotifier<SubtitleSettings> {
  SubtitleSettingsNotifier(this._storage) : super(SubtitleSettings.defaults) {
    _loadSettings();
  }

  final SubtitleSettingsStorage _storage;

  Future<void> _loadSettings() async {
    final loaded = await _storage.load();
    state = loaded;
  }

  Future<void> updateSettings(SubtitleSettings settings) async {
    state = settings;
    await _storage.save(settings);
  }

  Future<void> updateFontSize(double fontSize) async {
    final newSettings = state.copyWith(fontSize: fontSize);
    await updateSettings(newSettings);
  }

  Future<void> updateTextColor(Color color) async {
    final newSettings = state.copyWith(textColor: color);
    await updateSettings(newSettings);
  }

  Future<void> updateBackgroundColor(Color color) async {
    final newSettings = state.copyWith(backgroundColor: color);
    await updateSettings(newSettings);
  }

  Future<void> updateBackgroundOpacity(double opacity) async {
    final newSettings = state.copyWith(backgroundOpacity: opacity);
    await updateSettings(newSettings);
  }

  Future<void> updateColorPalettes({
    List<Color>? textColorPalette,
    List<Color>? backgroundColorPalette,
  }) async {
    final newSettings = state.copyWith(
      textColorPalette: textColorPalette,
      backgroundColorPalette: backgroundColorPalette,
    );
    await updateSettings(newSettings);
  }
}
