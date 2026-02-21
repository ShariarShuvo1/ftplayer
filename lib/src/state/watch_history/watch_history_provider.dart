import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../features/watch_history/data/watch_history_storage.dart';
import '../../features/watch_history/data/watch_history_models.dart';

final contentWatchHistoryProvider = FutureProvider.family
    .autoDispose<WatchHistory?, ({String ftpServerId, String contentId})>((
      ref,
      params,
    ) async {
      final storage = ref.read(watchHistoryStorageProvider);
      return storage.getWatchHistory(
        ftpServerId: params.ftpServerId,
        contentId: params.contentId,
      );
    });

final watchHistoryListProvider = FutureProvider.family
    .autoDispose<List<WatchHistory>, ({String? status, int limit, int page})>((
      ref,
      params,
    ) async {
      final storage = ref.read(watchHistoryStorageProvider);
      final histories = await storage.getAllWatchHistories(
        status: params.status,
      );

      final startIndex = (params.page - 1) * params.limit;
      final endIndex = startIndex + params.limit;

      if (startIndex >= histories.length) {
        return [];
      }

      return histories.sublist(
        startIndex,
        endIndex > histories.length ? histories.length : endIndex,
      );
    });

class WatchHistoryNotifier extends AutoDisposeAsyncNotifier<WatchHistory?> {
  Timer? _updateDebounceTimer;
  bool _hasUpdatePending = false;

  @override
  Future<WatchHistory?> build() async {
    ref.onDispose(() {
      _updateDebounceTimer?.cancel();
      _hasUpdatePending = false;
    });
    return null;
  }

  Future<void> updateStatus({
    required String ftpServerId,
    required String serverName,
    required String serverType,
    required String contentType,
    required String contentId,
    required String contentTitle,
    required WatchStatus status,
    Map<String, dynamic>? metadata,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final storage = ref.read(watchHistoryStorageProvider);

      final existing = await storage.getWatchHistory(
        ftpServerId: ftpServerId,
        contentId: contentId,
      );

      final now = DateTime.now();
      final history = WatchHistory(
        id: existing?.id ?? '${ftpServerId}_$contentId',
        userId: existing?.userId ?? 'local_user',
        ftpServerId: ftpServerId,
        serverName: serverName,
        serverType: serverType,
        contentType: contentType,
        contentId: contentId,
        contentTitle: contentTitle,
        status: status,
        progress: existing?.progress,
        seriesProgress: existing?.seriesProgress,
        metadata: metadata ?? existing?.metadata,
        lastWatchedAt: now,
        completedAt: status == WatchStatus.completed
            ? now
            : existing?.completedAt,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await storage.saveWatchHistory(history, immediate: true);
      return history;
    });
  }

  Future<void> updateProgress({
    required String ftpServerId,
    required String serverName,
    required String serverType,
    required String contentType,
    required String contentId,
    required String contentTitle,
    required double currentTime,
    required double duration,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeId,
    String? episodeTitle,
    Map<String, dynamic>? metadata,
    bool immediate = false,
  }) async {
    final percentage = duration > 0 ? (currentTime / duration) * 100 : 0.0;

    final progress = ProgressInfo(
      currentTime: currentTime,
      duration: duration,
      percentage: percentage,
    );

    _hasUpdatePending = true;
    _updateDebounceTimer?.cancel();

    if (immediate) {
      await _performProgressUpdate(
        ftpServerId,
        serverName,
        serverType,
        contentType,
        contentId,
        contentTitle,
        progress,
        seasonNumber,
        episodeNumber,
        episodeId,
        episodeTitle,
        metadata,
        immediate,
      );
    } else {
      _updateDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
        await _performProgressUpdate(
          ftpServerId,
          serverName,
          serverType,
          contentType,
          contentId,
          contentTitle,
          progress,
          seasonNumber,
          episodeNumber,
          episodeId,
          episodeTitle,
          metadata,
          immediate,
        );
      });
    }
  }

  Future<void> _performProgressUpdate(
    String ftpServerId,
    String serverName,
    String serverType,
    String contentType,
    String contentId,
    String contentTitle,
    ProgressInfo progress,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeId,
    String? episodeTitle,
    Map<String, dynamic>? metadata,
    bool immediate,
  ) async {
    try {
      final storage = ref.read(watchHistoryStorageProvider);

      final existing = await storage.getWatchHistory(
        ftpServerId: ftpServerId,
        contentId: contentId,
      );

      final now = DateTime.now();
      List<SeasonProgress>? seriesProgress = existing?.seriesProgress;

      if (contentType == 'series' &&
          seasonNumber != null &&
          episodeNumber != null) {
        seriesProgress = _updateSeriesProgress(
          existing?.seriesProgress,
          seasonNumber,
          episodeNumber,
          episodeId,
          episodeTitle,
          progress,
          now,
        );
      }

      final mergedMetadata = <String, dynamic>{
        ...?existing?.metadata,
        ...?metadata,
      };

      final history = WatchHistory(
        id: existing?.id ?? '${ftpServerId}_$contentId',
        userId: existing?.userId ?? 'local_user',
        ftpServerId: ftpServerId,
        serverName: serverName,
        serverType: serverType,
        contentType: contentType,
        contentId: contentId,
        contentTitle: contentTitle,
        status: existing?.status ?? WatchStatus.watching,
        progress: (contentType == 'movie' || contentType == 'singleVideo')
            ? progress
            : existing?.progress,
        seriesProgress: seriesProgress,
        metadata: mergedMetadata,
        lastWatchedAt: now,
        completedAt: existing?.completedAt,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );

      await storage.saveWatchHistory(history, immediate: immediate);

      if (_hasUpdatePending) {
        try {
          state = AsyncValue.data(history);
        } catch (_) {}
      }
    } catch (e, st) {
      Logger().e('Error updating progress: $e', stackTrace: st);
    } finally {
      _hasUpdatePending = false;
    }
  }

  List<SeasonProgress> _updateSeriesProgress(
    List<SeasonProgress>? existingProgress,
    int seasonNumber,
    int episodeNumber,
    String? episodeId,
    String? episodeTitle,
    ProgressInfo progress,
    DateTime lastWatchedAt,
  ) {
    final seasons = List<SeasonProgress>.from(existingProgress ?? []);

    final seasonIndex = seasons.indexWhere(
      (s) => s.seasonNumber == seasonNumber,
    );

    if (seasonIndex == -1) {
      seasons.add(
        SeasonProgress(
          seasonNumber: seasonNumber,
          seasonId: null,
          episodes: [
            EpisodeProgress(
              episodeNumber: episodeNumber,
              episodeId: episodeId,
              episodeTitle: episodeTitle,
              status: WatchStatus.watching,
              progress: progress,
              lastWatchedAt: lastWatchedAt,
            ),
          ],
        ),
      );
    } else {
      final season = seasons[seasonIndex];
      final episodes = List<EpisodeProgress>.from(season.episodes);
      final episodeIndex = episodes.indexWhere(
        (e) => e.episodeNumber == episodeNumber,
      );

      if (episodeIndex == -1) {
        episodes.add(
          EpisodeProgress(
            episodeNumber: episodeNumber,
            episodeId: episodeId,
            episodeTitle: episodeTitle,
            status: WatchStatus.watching,
            progress: progress,
            lastWatchedAt: lastWatchedAt,
          ),
        );
      } else {
        episodes[episodeIndex] = EpisodeProgress(
          episodeNumber: episodeNumber,
          episodeId: episodeId ?? episodes[episodeIndex].episodeId,
          episodeTitle: episodeTitle ?? episodes[episodeIndex].episodeTitle,
          status: episodes[episodeIndex].status,
          progress: progress,
          lastWatchedAt: lastWatchedAt,
        );
      }

      seasons[seasonIndex] = SeasonProgress(
        seasonNumber: seasonNumber,
        seasonId: season.seasonId,
        episodes: episodes,
      );
    }

    return seasons;
  }

  Future<void> changeStatus(
    String ftpServerId,
    String contentId,
    WatchStatus newStatus,
  ) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final storage = ref.read(watchHistoryStorageProvider);

      final existing = await storage.getWatchHistory(
        ftpServerId: ftpServerId,
        contentId: contentId,
      );

      if (existing == null) return null;

      final now = DateTime.now();
      final history = WatchHistory(
        id: existing.id,
        userId: existing.userId,
        ftpServerId: existing.ftpServerId,
        serverName: existing.serverName,
        serverType: existing.serverType,
        contentType: existing.contentType,
        contentId: existing.contentId,
        contentTitle: existing.contentTitle,
        status: newStatus,
        progress: existing.progress,
        seriesProgress: existing.seriesProgress,
        metadata: existing.metadata,
        lastWatchedAt: now,
        completedAt: newStatus == WatchStatus.completed
            ? now
            : existing.completedAt,
        createdAt: existing.createdAt,
        updatedAt: now,
      );

      await storage.saveWatchHistory(history, immediate: true);
      return history;
    });
  }

  Future<void> deleteHistory(String ftpServerId, String contentId) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final storage = ref.read(watchHistoryStorageProvider);
      await storage.deleteWatchHistory(
        ftpServerId: ftpServerId,
        contentId: contentId,
      );
      return null;
    });
  }

  Future<void> deleteEpisodeFromHistory(
    String ftpServerId,
    String contentId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final storage = ref.read(watchHistoryStorageProvider);

      final existing = await storage.getWatchHistory(
        ftpServerId: ftpServerId,
        contentId: contentId,
      );

      if (existing == null || existing.seriesProgress == null) {
        return null;
      }

      final seasons = List<SeasonProgress>.from(existing.seriesProgress!);
      final seasonIndex = seasons.indexWhere(
        (s) => s.seasonNumber == seasonNumber,
      );

      if (seasonIndex == -1) return existing;

      final season = seasons[seasonIndex];
      final episodes = season.episodes
          .where((e) => e.episodeNumber != episodeNumber)
          .toList();

      if (episodes.isEmpty) {
        seasons.removeAt(seasonIndex);
      } else {
        seasons[seasonIndex] = SeasonProgress(
          seasonNumber: seasonNumber,
          seasonId: season.seasonId,
          episodes: episodes,
        );
      }

      if (seasons.isEmpty) {
        await storage.deleteWatchHistory(
          ftpServerId: ftpServerId,
          contentId: contentId,
        );
        return null;
      }

      final now = DateTime.now();
      final history = WatchHistory(
        id: existing.id,
        userId: existing.userId,
        ftpServerId: existing.ftpServerId,
        serverName: existing.serverName,
        serverType: existing.serverType,
        contentType: existing.contentType,
        contentId: existing.contentId,
        contentTitle: existing.contentTitle,
        status: existing.status,
        progress: existing.progress,
        seriesProgress: seasons,
        metadata: existing.metadata,
        lastWatchedAt: existing.lastWatchedAt,
        completedAt: existing.completedAt,
        createdAt: existing.createdAt,
        updatedAt: now,
      );

      await storage.saveWatchHistory(history, immediate: true);
      return history;
    });
  }

  Future<void> deleteAllByStatus(WatchStatus status) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final storage = ref.read(watchHistoryStorageProvider);
      await storage.deleteAllByStatus(status.value);
      return null;
    });
  }
}

final watchHistoryNotifierProvider =
    AutoDisposeAsyncNotifierProvider<WatchHistoryNotifier, WatchHistory?>(
      WatchHistoryNotifier.new,
    );
