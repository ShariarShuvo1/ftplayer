import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../features/pip/pip_overlay.dart';
import '../state/pip/pip_provider.dart';
import '../state/connectivity/connectivity_provider.dart';
import '../state/connectivity/offline_navigation_handler.dart';
import '../state/watch_history/watch_history_provider.dart';
import '../features/watch_history/data/watch_history_storage.dart';
import '../features/home/data/home_models.dart';
import '../features/ftp_servers/data/ftp_servers_local_data.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final Logger _logger = Logger();

  Future<void> _closePipAndSaveProgress(WidgetRef ref) async {
    final pipState = ref.read(pipProvider);

    if (!pipState.isActive || pipState.player == null) {
      return;
    }

    try {
      final currentTime = pipState.player!.state.position.inSeconds.toDouble();
      final duration = pipState.player!.state.duration.inSeconds.toDouble();

      if (duration > 0 && pipState.contentItemJson != null) {
        try {
          final contentItem = ContentItem.fromJson(pipState.contentItemJson!);
          final server = FtpServersLocalData.getServerByName(
            contentItem.serverName,
          );

          if (server != null) {
            ref
                .read(watchHistoryNotifierProvider.notifier)
                .updateProgress(
                  ftpServerId: server.id,
                  serverName: contentItem.serverName,
                  serverType: contentItem.serverType,
                  contentType: contentItem.contentType ?? 'movie',
                  contentId: contentItem.id,
                  contentTitle: contentItem.title,
                  currentTime: currentTime,
                  duration: duration,
                  seasonNumber: pipState.currentSeasonNumber,
                  episodeNumber: pipState.currentEpisodeNumber,
                  episodeId: pipState.currentEpisodeId,
                  episodeTitle: pipState.currentEpisodeTitle,
                  metadata: {
                    'serverName': contentItem.serverName,
                    'posterUrl': contentItem.posterUrl,
                    'year': contentItem.year,
                    'quality': contentItem.quality,
                  },
                  immediate: true,
                );

            final storage = ref.read(watchHistoryStorageProvider);
            await storage.flush();
          }
        } catch (e) {
          _logger.e('[App] Error saving PIP progress: $e');
        }
      }

      ref.read(pipProvider.notifier).deactivatePip(disposePlayer: true);
    } catch (e) {
      _logger.e('[App] Error closing PIP: $e');
      ref.read(pipProvider.notifier).deactivatePip(disposePlayer: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(goRouterProvider);
    final pipState = ref.watch(pipProvider);

    ref.listen<bool>(offlineModeProvider, (previous, next) {
      if (previous == false && next == true) {
        if (pipState.isActive) {
          _closePipAndSaveProgress(ref);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final currentPath =
              router.routerDelegate.currentConfiguration.uri.path;
          final handler = ref.read(offlineNavigationHandlerProvider);
          handler.handleOfflineTransition(router, currentPath);
        });
      } else if (previous == true && next == false) {
        if (pipState.isActive) {
          _closePipAndSaveProgress(ref);
        }
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
