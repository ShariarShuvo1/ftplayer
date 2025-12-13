import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  return TokenStorage(const FlutterSecureStorage());
});

class TokenStorage {
  TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const _key = 'auth_token';

  AndroidOptions get _androidOptions =>
      const AndroidOptions(resetOnError: true);

  IOSOptions get _iosOptions =>
      const IOSOptions(accessibility: KeychainAccessibility.first_unlock);

  Future<String?> readToken() async {
    try {
      return await _storage.read(
        key: _key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> writeToken(String token) async {
    try {
      await _storage.write(
        key: _key,
        value: token,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } catch (_) {
      await deleteToken();
      rethrow;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _storage.delete(
        key: _key,
        aOptions: _androidOptions,
        iOptions: _iosOptions,
      );
    } catch (_) {}
  }
}
