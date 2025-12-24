import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_error.dart';
import '../../features/auth/data/auth_repository.dart';
import '../connectivity/connectivity_provider.dart';

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession?>(AuthController.new);
final authInitializedProvider = StateProvider<bool>((ref) => false);

class AuthController extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final repo = ref.read(authRepositoryProvider);

    try {
      final token = await repo.tokenStorage.readToken();
      if (token == null || token.isEmpty) {
        ref.read(authInitializedProvider.notifier).state = true;
        return null;
      }

      final isOffline = ref.read(offlineModeProvider);

      if (isOffline) {
        final session = await repo.restoreSessionOffline();
        ref.read(authInitializedProvider.notifier).state = true;
        return session;
      }

      final session = await repo.restoreSession();
      ref.read(authInitializedProvider.notifier).state = true;
      return session;
    } catch (_) {
      ref.read(authInitializedProvider.notifier).state = true;
      return null;
    }
  }

  Future<String> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await repo.signup(
        name: name,
        email: email,
        password: password,
      );
      return session;
    });
    return state.when(
      data: (_) => 'Account created',
      loading: () => 'Account created',
      error: (e, _) => throw ApiError.from(e),
    );
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final repo = ref.read(authRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = await repo.login(email: email, password: password);
      return session;
    });
    return state.when(
      data: (_) => 'Login successful',
      loading: () => 'Login successful',
      error: (e, _) => throw ApiError.from(e),
    );
  }

  Future<void> logout() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.logout();
    state = const AsyncData(null);
  }
}
