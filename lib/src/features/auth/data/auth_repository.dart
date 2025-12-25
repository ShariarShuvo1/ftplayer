import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import '../../../core/storage/token_storage.dart';
import 'auth_api.dart';
import 'auth_models.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dio = ref.read(dioProvider);
  final storage = ref.read(tokenStorageProvider);
  return AuthRepository(api: AuthApi(dio), tokenStorage: storage);
});

class AuthSession {
  AuthSession({required this.token, required this.user});

  final String token;
  final UserDto user;
}

class AuthRepository {
  AuthRepository({required this.api, required this.tokenStorage});

  final AuthApi api;
  final TokenStorage tokenStorage;

  Future<AuthSession> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final res = await api.signup(name: name, email: email, password: password);
    await tokenStorage.writeToken(res.token);
    await tokenStorage.writeUserName(res.user.name);
    return AuthSession(token: res.token, user: res.user);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final res = await api.login(email: email, password: password);
    await tokenStorage.writeToken(res.token);
    await tokenStorage.writeUserName(res.user.name);
    return AuthSession(token: res.token, user: res.user);
  }

  Future<void> logout() async {
    await tokenStorage.deleteToken();
    await tokenStorage.deleteUserName();
  }

  Future<AuthSession?> restoreSession() async {
    final token = await tokenStorage.readToken();
    if (token == null || token.isEmpty) return null;
    final me = await api.me();
    await tokenStorage.writeUserName(me.user.name);
    return AuthSession(token: token, user: me.user);
  }

  Future<AuthSession?> restoreSessionOffline() async {
    final token = await tokenStorage.readToken();
    if (token == null || token.isEmpty) return null;
    final cachedUserName = await tokenStorage.readUserName();
    return AuthSession(
      token: token,
      user: UserDto(id: '', name: cachedUserName ?? 'User', email: ''),
    );
  }
}
