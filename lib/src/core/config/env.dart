import 'package:flutter_dotenv/flutter_dotenv.dart';

class Env {
  const Env._();

  static String get apiBaseUrl {
    final raw = dotenv.env['API_URL']?.trim();
    final fallback = 'https://ftplayer-backend.vercel.app/api';
    final value = (raw == null || raw.isEmpty) ? fallback : raw;
    final normalized = _normalizeBaseUrl(value);
    return normalized;
  }

  static String _normalizeBaseUrl(String value) {
    final trimmed = value.endsWith('/')
        ? value.substring(0, value.length - 1)
        : value;
    if (trimmed.endsWith('/api')) return trimmed;
    return '$trimmed/api';
  }
}
