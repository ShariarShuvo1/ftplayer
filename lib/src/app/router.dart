import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/presentation/first_time_welcome_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/ftp_servers/presentation/server_scan_screen.dart';
import '../features/content_details/presentation/content_details_screen.dart';
import '../features/watch_history/presentation/watch_history_screen.dart';
import '../features/search/presentation/search_result_screen.dart';
import '../features/downloads/presentation/downloads_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/home/data/home_models.dart';
import '../core/storage/first_time_storage.dart';
import '../state/connectivity/connectivity_provider.dart';

final drawerScreenPaths = {
  WatchHistoryScreen.path,
  DownloadsScreen.path,
  SettingsScreen.path,
  SearchResultScreen.path,
};

void navigateToDrawerScreen(BuildContext context, String path) {
  final currentPath = GoRouterState.of(context).matchedLocation;

  if (drawerScreenPaths.contains(currentPath) &&
      drawerScreenPaths.contains(path) &&
      currentPath != SearchResultScreen.path) {
    context.pushReplacement(path);
  } else {
    context.push(path);
  }
}

final initializationProvider = FutureProvider<bool>((ref) async {
  final storage = ref.read(firstTimeStorageProvider);
  return await storage.hasShownWelcome();
});

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = AppRouterNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: notifier,
    redirect: (context, state) async {
      final isOffline = ref.read(offlineModeProvider);
      final isFirstTimeWelcome =
          state.matchedLocation == FirstTimeWelcomeScreen.path;
      final isServerScan = state.matchedLocation == ServerScanScreen.path;

      final initState = ref.read(initializationProvider);

      if (initState.isLoading) {
        return '/';
      }

      final hasShownWelcome = initState.valueOrNull ?? false;

      if (!hasShownWelcome) {
        if (isFirstTimeWelcome) return null;
        return FirstTimeWelcomeScreen.path;
      }

      if (state.matchedLocation == '/' || isFirstTimeWelcome) {
        if (isOffline) {
          return HomeScreen.path;
        }
        return ServerScanScreen.path;
      }

      if (isServerScan && isOffline) {
        return HomeScreen.path;
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      GoRoute(
        path: FirstTimeWelcomeScreen.path,
        builder: (context, state) => const FirstTimeWelcomeScreen(),
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
        path: ContentDetailsScreen.path,
        pageBuilder: (context, state) {
          final contentItem = state.extra as ContentItem;
          return CustomTransitionPage(
            key: state.pageKey,
            opaque: false,
            barrierColor: Colors.transparent,
            transitionDuration: const Duration(milliseconds: 180),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            child: ContentDetailsScreen(contentItem: contentItem),
          );
        },
      ),
      GoRoute(
        path: WatchHistoryScreen.path,
        builder: (context, state) => const WatchHistoryScreen(),
      ),
      GoRoute(
        path: DownloadsScreen.path,
        builder: (context, state) => const DownloadsScreen(),
      ),
      GoRoute(
        path: SettingsScreen.path,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: SearchResultScreen.path,
        builder: (context, state) {
          final query = state.extra as String? ?? '';
          return SearchResultScreen(initialQuery: query);
        },
      ),
    ],
  );
});

class AppRouterNotifier extends ChangeNotifier {
  AppRouterNotifier(this.ref) {
    _sub = ref.listen(initializationProvider, (prev, next) {
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
