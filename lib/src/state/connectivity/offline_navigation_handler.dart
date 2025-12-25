import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/home_screen.dart';
import '../../features/downloads/presentation/downloads_screen.dart';
import '../../features/content_details/presentation/content_details_screen.dart';
import '../downloads/download_provider.dart';
import '../content/current_playing_content_provider.dart';
import 'connectivity_provider.dart';

final offlineNavigationHandlerProvider = Provider<OfflineNavigationHandler>(
  (ref) => OfflineNavigationHandler(ref),
);

class OfflineNavigationHandler {
  OfflineNavigationHandler(this.ref);

  final Ref ref;

  void handleOfflineTransition(GoRouter router, String currentPath) {
    final isOffline = ref.read(offlineModeProvider);
    if (!isOffline) return;

    if (currentPath == DownloadsScreen.path) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentPath == ContentDetailsScreen.path) {
        _handleContentDetailsOffline(router);
      } else {
        router.go(HomeScreen.path);
      }
    });
  }

  void _handleContentDetailsOffline(GoRouter router) {
    final currentPlaying = ref.read(currentPlayingContentProvider);

    if (currentPlaying == null) {
      router.go(HomeScreen.path);
      return;
    }

    if (currentPlaying.seasonNumber != null &&
        currentPlaying.episodeNumber != null) {
      final isDownloaded = ref.read(
        isContentDownloadedProvider((
          contentId: currentPlaying.contentId,
          seasonNumber: currentPlaying.seasonNumber,
          episodeNumber: currentPlaying.episodeNumber,
        )),
      );

      if (isDownloaded) {
        return;
      }
    } else {
      final isDownloaded = ref.read(
        isContentDownloadedProvider((
          contentId: currentPlaying.contentId,
          seasonNumber: null,
          episodeNumber: null,
        )),
      );

      if (isDownloaded) {
        return;
      }
    }

    router.go(HomeScreen.path);
  }
}
