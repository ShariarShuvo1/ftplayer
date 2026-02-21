import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:media_kit_video/media_kit_video.dart';

class SubtitleSettings {
  const SubtitleSettings({
    required this.fontSize,
    required this.textColor,
    required this.backgroundColor,
    required this.backgroundOpacity,
    required this.textColorPalette,
    required this.backgroundColorPalette,
  });

  final double fontSize;
  final Color textColor;
  final Color backgroundColor;
  final double backgroundOpacity;
  final List<Color> textColorPalette;
  final List<Color> backgroundColorPalette;

  SubtitleSettings copyWith({
    double? fontSize,
    Color? textColor,
    Color? backgroundColor,
    double? backgroundOpacity,
    List<Color>? textColorPalette,
    List<Color>? backgroundColorPalette,
  }) {
    return SubtitleSettings(
      fontSize: fontSize ?? this.fontSize,
      textColor: textColor ?? this.textColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      textColorPalette: textColorPalette ?? this.textColorPalette,
      backgroundColorPalette:
          backgroundColorPalette ?? this.backgroundColorPalette,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fontSize': fontSize,
      'textColor': textColor.toARGB32(),
      'backgroundColor': backgroundColor.toARGB32(),
      'backgroundOpacity': backgroundOpacity,
      'textColorPalette': textColorPalette.map((c) => c.toARGB32()).toList(),
      'backgroundColorPalette': backgroundColorPalette
          .map((c) => c.toARGB32())
          .toList(),
    };
  }

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) {
    return SubtitleSettings(
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 36.0,
      textColor: Color((json['textColor'] as int?) ?? Colors.white.toARGB32()),
      backgroundColor: Color(
        (json['backgroundColor'] as int?) ?? Colors.black.toARGB32(),
      ),
      backgroundOpacity:
          (json['backgroundOpacity'] as num?)?.toDouble() ?? 0.75,
      textColorPalette:
          (json['textColorPalette'] as List<dynamic>?)
              ?.map((e) => Color(e as int))
              .toList() ??
          defaults.textColorPalette,
      backgroundColorPalette:
          (json['backgroundColorPalette'] as List<dynamic>?)
              ?.map((e) => Color(e as int))
              .toList() ??
          defaults.backgroundColorPalette,
    );
  }

  SubtitleViewConfiguration toViewConfiguration() {
    return SubtitleViewConfiguration(
      visible: true,
      style: TextStyle(
        height: 1.4,
        fontSize: fontSize,
        color: textColor,
        backgroundColor: backgroundColor.withValues(alpha: backgroundOpacity),
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
      padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 32.0),
    );
  }

  static const SubtitleSettings defaults = SubtitleSettings(
    fontSize: 36.0,
    textColor: Colors.white,
    backgroundColor: Colors.black,
    backgroundOpacity: 0.75,
    textColorPalette: [
      Colors.white,
      Color(0xFFFFF59D),
      Color(0xFFB2EBF2),
      Color(0xFFC8E6C9),
      Color(0xFFFFB3BA),
      Color(0xFFBAE1FF),
      Color(0xFFFFDFBA),
      Color(0xFFE0BBE4),
      Color(0xFFD4F1F4),
    ],
    backgroundColorPalette: [
      Colors.black,
      Color(0xFF1B1B1B),
      Color(0xFF2E2E2E),
      Color(0xFF0D1117),
      Color(0xFF1A1A2E),
      Color(0xFF16213E),
      Color(0xFF0F0F23),
      Color(0xFF1E1E3F),
      Color(0xFF141B2B),
    ],
  );
}

class SubtitleSettingsStorage {
  const SubtitleSettingsStorage(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'subtitle_settings';

  AndroidOptions get _androidOptions =>
      const AndroidOptions(resetOnError: true);
  IOSOptions get _iosOptions =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  Future<SubtitleSettings> load() async {
    try {
      final raw = await _storage.read(
        key: _key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      if (raw == null || raw.isEmpty) return SubtitleSettings.defaults;
      final jsonMap = jsonDecode(raw) as Map<String, dynamic>;
      return SubtitleSettings.fromJson(jsonMap);
    } catch (_) {
      return SubtitleSettings.defaults;
    }
  }

  Future<void> save(SubtitleSettings settings) async {
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
