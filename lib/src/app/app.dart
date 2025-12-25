import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pip/pip_overlay.dart';
import '../state/pip/pip_provider.dart';
import '../state/connectivity/connectivity_provider.dart';
import '../state/connectivity/offline_navigation_handler.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final pipState = ref.watch(pipProvider);

    ref.listen<bool>(offlineModeProvider, (previous, next) {
      if (previous == false && next == true) {
        final currentPath = router.routerDelegate.currentConfiguration.uri.path;
        final handler = ref.read(offlineNavigationHandlerProvider);
        handler.handleOfflineTransition(router, currentPath);
      }
    });

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (pipState.isActive) const PipOverlay(),
          ],
        );
      },
    );
  }
}
