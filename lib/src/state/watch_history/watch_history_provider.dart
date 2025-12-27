import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../features/watch_history/data/watch_history_api.dart';
import '../../features/watch_history/data/watch_history_models.dart';
import '../ftp/working_ftp_servers_provider.dart';

final watchHistoryApiProvider = Provider<WatchHistoryApi>((ref) {
  final dio = ref.watch(dioProvider);
  return WatchHistoryApi(dio);
});

final contentWatchHistoryProvider = FutureProvider.family
    .autoDispose<WatchHistory?, ({String ftpServerId, String contentId})>((
      ref,
      params,
    ) async {
      final api = ref.watch(watchHistoryApiProvider);
      final response = await api.getContentWatchHistory(
        ftpServerId: params.ftpServerId,
        contentId: params.contentId,
      );
      return response?.watchHistory;
    });

final watchHistoryListProvider = FutureProvider.family
    .autoDispose<
      WatchHistoryListResponse,
      ({String? status, int limit, int page})
    >((ref, params) async {
      final workingServersAsync = ref.watch(workingFtpServersProvider);
      final api = ref.watch(watchHistoryApiProvider);

      final response = await api.getWatchHistory(
        status: params.status,
        limit: params.limit,
        page: params.page,
      );

      return workingServersAsync.when(
        data: (workingServers) {
          if (workingServers.isEmpty) {
            return WatchHistoryListResponse(
              message: response.message,
              watchHistories: [],
              pagination: response.pagination,
            );
          }

          final workingServerIds = workingServers.map((s) => s.id).toSet();

          final filteredHistories = response.watchHistories
              .where(
                (history) => workingServerIds.contains(history.ftpServerId),
              )
              .toList();

          return WatchHistoryListResponse(
            message: response.message,
            watchHistories: filteredHistories,
            pagination: response.pagination,
          );
        },
        loading: () => response,
        error: (_, _) => response,
      );
    });

class WatchHistoryNotifier extends AutoDisposeAsyncNotifier<WatchHistory?> {
  @override
  Future<WatchHistory?> build() async {
    return null;
  }

  Future<void> updateStatus({
    required String ftpServerId,
    required String serverType,
    required String contentType,
    required String contentId,
    required String contentTitle,
    required WatchStatus status,
    Map<String, dynamic>? metadata,
  }) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final api = ref.read(watchHistoryApiProvider);
      final response = await api.updateWatchProgress(
        ftpServerId: ftpServerId,
        serverType: serverType,
        contentType: contentType,
        contentId: contentId,
        contentTitle: contentTitle,
        status: status.value,
        metadata: metadata,
      );
      return response.watchHistory;
    });
  }

  Future<void> updateProgress({
    required String ftpServerId,
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
  }) async {
    final percentage = duration > 0 ? (currentTime / duration) * 100 : 0.0;

    final progress = {
      'currentTime': currentTime,
      'duration': duration,
      'percentage': percentage,
    };

    state = await AsyncValue.guard(() async {
      final api = ref.read(watchHistoryApiProvider);
      final response = await api.updateWatchProgress(
        ftpServerId: ftpServerId,
        serverType: serverType,
        contentType: contentType,
        contentId: contentId,
        contentTitle: contentTitle,
        progress: progress,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeId: episodeId,
        episodeTitle: episodeTitle,
        metadata: metadata,
      );
      return response.watchHistory;
    });
  }

  Future<void> changeStatus(String id, WatchStatus newStatus) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final api = ref.read(watchHistoryApiProvider);
      final response = await api.updateContentStatus(
        id: id,
        status: newStatus.value,
      );
      return response.watchHistory;
    });
  }

  Future<void> deleteHistory(String id) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final api = ref.read(watchHistoryApiProvider);
      await api.deleteWatchHistory(id);
      return null;
    });
  }

  Future<void> deleteEpisodeFromHistory(
    String id,
    int seasonNumber,
    int episodeNumber,
  ) async {
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      final api = ref.read(watchHistoryApiProvider);
      final response = await api.deleteEpisodeFromWatchHistory(
        id: id,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
      return response.watchHistory;
    });
  }
}

final watchHistoryNotifierProvider =
    AutoDisposeAsyncNotifierProvider<WatchHistoryNotifier, WatchHistory?>(
      WatchHistoryNotifier.new,
    );
