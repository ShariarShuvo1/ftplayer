import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/auth/presentation/welcome_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/auth/presentation/profile_screen.dart';
import '../features/ftp_servers/presentation/server_scan_screen.dart';
import '../state/auth/auth_controller.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = AuthRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: SplashScreen.path,
    refreshListenable: notifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);

      final isSplash = state.matchedLocation == SplashScreen.path;
      final isWelcome = state.matchedLocation == WelcomeScreen.path;
      final isLogin = state.matchedLocation == LoginScreen.path;
      final isSignup = state.matchedLocation == SignupScreen.path;

      final initialized = ref.read(authInitializedProvider);

      if (auth.isLoading && !initialized) {
        return isSplash ? null : SplashScreen.path;
      }

      final session = auth.valueOrNull;
      final isAuthed = session != null;

      if (!isAuthed) {
        if (isSplash) return WelcomeScreen.path;
        if (isWelcome || isLogin || isSignup) return null;
        return WelcomeScreen.path;
      }

      if (isSplash || isWelcome || isLogin || isSignup) {
        return ServerScanScreen.path;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: SplashScreen.path,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: WelcomeScreen.path,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: LoginScreen.path,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: SignupScreen.path,
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: ServerScanScreen.path,
        builder: (context, state) => const ServerScanScreen(),
      ),
      GoRoute(
        path: HomeScreen.path,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: ProfileScreen.path,
        builder: (context, state) => const ProfileScreen(),
      ),
    ],
  );
});

class AuthRouterNotifier extends ChangeNotifier {
  AuthRouterNotifier(this.ref) {
    _sub = ref.listen(authControllerProvider, (prev, next) {
      notifyListeners();
    });
  }

  final Ref ref;
  late final ProviderSubscription _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
