import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final firstTimeStorageProvider = Provider<FirstTimeStorage>((ref) {
  return FirstTimeStorage(const FlutterSecureStorage());
});

class FirstTimeStorage {
  FirstTimeStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'first_time_welcome_shown';

  AndroidOptions get _androidOptions =>
      const AndroidOptions(resetOnError: true);

  IOSOptions get _iosOptions =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  Future<bool> hasShownWelcome() async {
    try {
      final value = await _storage.read(
        key: _key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
      return value == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> markWelcomeShown() async {
    try {
      await _storage.write(
        key: _key,
        value: 'true',
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } catch (_) {}
  }
}
