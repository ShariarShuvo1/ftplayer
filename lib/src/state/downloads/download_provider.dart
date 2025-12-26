import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/downloads/data/download_manager.dart';
import '../../features/downloads/data/download_models.dart';

final downloadManagerProvider = Provider<DownloadManager>((ref) {
  return DownloadManager.instance;
});

final downloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) async* {
  final manager = ref.watch(downloadManagerProvider);
  await manager.initialize();
  yield manager.tasks;
  yield* manager.tasksStream;
});

final downloadedContentProvider = StreamProvider<List<DownloadedContent>>((
  ref,
) async* {
  final manager = ref.watch(downloadManagerProvider);
  await manager.initialize();
  yield manager.downloads;
  yield* manager.downloadsStream;
});

final activeDownloadProvider = StreamProvider<DownloadTask?>((ref) async* {
  final manager = ref.watch(downloadManagerProvider);
  await manager.initialize();
  yield manager.activeDownload;
  yield* manager.activeDownloadStream;
});

final isContentDownloadedProvider =
    Provider.family<
      bool,
      ({String contentId, int? seasonNumber, int? episodeNumber})
    >((ref, params) {
      final downloadsAsync = ref.watch(downloadedContentProvider);
      return downloadsAsync.when(
        data: (downloads) => downloads.any((d) {
          if (d.contentId != params.contentId) return false;
          if (params.seasonNumber != null && params.episodeNumber != null) {
            return d.seasonNumber == params.seasonNumber &&
                d.episodeNumber == params.episodeNumber;
          }
          return d.seasonNumber == null && d.episodeNumber == null;
        }),
        loading: () => false,
        error: (_, _) => false,
      );
    });

final isContentDownloadingProvider =
    Provider.family<
      bool,
      ({String contentId, int? seasonNumber, int? episodeNumber})
    >((ref, params) {
      final tasksAsync = ref.watch(downloadTasksProvider);
      return tasksAsync.when(
        data: (tasks) => tasks.any((t) {
          if (t.contentId != params.contentId) return false;
          if (t.status != DownloadStatus.downloading &&
              t.status != DownloadStatus.queued &&
              t.status != DownloadStatus.paused) {
            return false;
          }
          if (params.seasonNumber != null && params.episodeNumber != null) {
            return t.seasonNumber == params.seasonNumber &&
                t.episodeNumber == params.episodeNumber;
          }
          return t.seasonNumber == null && t.episodeNumber == null;
        }),
        loading: () => false,
        error: (_, _) => false,
      );
    });

final contentDownloadTaskProvider =
    Provider.family<
      DownloadTask?,
      ({String contentId, int? seasonNumber, int? episodeNumber})
    >((ref, params) {
      final tasksAsync = ref.watch(downloadTasksProvider);
      return tasksAsync.when(
        data: (tasks) => tasks.where((t) {
          if (t.contentId != params.contentId) return false;
          if (params.seasonNumber != null && params.episodeNumber != null) {
            return t.seasonNumber == params.seasonNumber &&
                t.episodeNumber == params.episodeNumber;
          }
          return t.seasonNumber == null && t.episodeNumber == null;
        }).firstOrNull,
        loading: () => null,
        error: (_, _) => null,
      );
    });

final downloadedContentItemProvider =
    Provider.family<
      DownloadedContent?,
      ({String contentId, int? seasonNumber, int? episodeNumber})
    >((ref, params) {
      final downloadsAsync = ref.watch(downloadedContentProvider);
      return downloadsAsync.when(
        data: (downloads) => downloads.where((d) {
          if (d.contentId != params.contentId) return false;
          if (params.seasonNumber != null && params.episodeNumber != null) {
            return d.seasonNumber == params.seasonNumber &&
                d.episodeNumber == params.episodeNumber;
          }
          return d.seasonNumber == null && d.episodeNumber == null;
        }).firstOrNull,
        loading: () => null,
        error: (_, _) => null,
      );
    });

class DownloadNotifier extends Notifier<void> {
  @override
  void build() {}

  Future<void> addDownload({
    required String contentId,
    required String title,
    required String posterUrl,
    required String description,
    required String serverName,
    required String serverType,
    required String ftpServerId,
    required String contentType,
    required String videoUrl,
    String? year,
    String? quality,
    double? rating,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
    String? seriesTitle,
    int? totalSeasons,
    Map<String, dynamic>? metadata,
  }) async {
    final manager = ref.read(downloadManagerProvider);
    await manager.addDownload(
      contentId: contentId,
      title: title,
      posterUrl: posterUrl,
      description: description,
      serverName: serverName,
      serverType: serverType,
      ftpServerId: ftpServerId,
      contentType: contentType,
      videoUrl: videoUrl,
      year: year,
      quality: quality,
      rating: rating,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      seriesTitle: seriesTitle,
      totalSeasons: totalSeasons,
      metadata: metadata,
    );
  }

  Future<void> pauseDownload(String taskId) async {
    final manager = ref.read(downloadManagerProvider);
    await manager.pauseDownload(taskId);
  }

  Future<void> pauseAllDownloads() async {
    final manager = ref.read(downloadManagerProvider);
    await manager.pauseAllDownloads();
  }

  Future<void> resumeDownload(String taskId) async {
    final manager = ref.read(downloadManagerProvider);
    final activeDownload = manager.activeDownload;
    if (activeDownload != null && activeDownload.id != taskId) {
      await manager.pauseDownload(activeDownload.id);
    }
    await manager.resumeDownload(taskId);
  }

  Future<void> cancelDownload(String taskId) async {
    final manager = ref.read(downloadManagerProvider);
    await manager.cancelDownload(taskId);
  }

  Future<void> deleteDownload(String downloadId) async {
    final manager = ref.read(downloadManagerProvider);
    await manager.deleteDownload(downloadId);
  }

  Future<void> retryDownload(String taskId) async {
    final manager = ref.read(downloadManagerProvider);
    await manager.retryDownload(taskId);
  }

  Future<void> clearAllCaches() async {
    final manager = ref.read(downloadManagerProvider);
    await manager.clearAllCaches();
  }
}

final downloadNotifierProvider = NotifierProvider<DownloadNotifier, void>(
  DownloadNotifier.new,
);

final storageUsageProvider = FutureProvider<int>((ref) async {
  final manager = ref.watch(downloadManagerProvider);
  await manager.initialize();
  return manager.getStorageUsage();
});
