import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../core/network/dio_provider.dart';
import '../../features/content_details/data/content_details_api.dart';
import '../../features/content_details/data/content_details_models.dart';
import '../../features/watch_history/data/watch_history_models.dart';
import '../../features/watch_history/data/watch_history_storage.dart';
import '../amaderftp/amaderftp_session_provider.dart';
import '../ftp/working_ftp_servers_provider.dart';

final contentDetailsApiProvider = Provider<ContentDetailsApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ContentDetailsApi(dio);
});

final _logger = Logger();

final contentDetailsProvider = FutureProvider.family
    .autoDispose<
      ContentDetails,
      ({
        String contentId,
        String serverName,
        String serverType,
        Map<String, dynamic>? initialData,
      })
    >((ref, params) async {
      try {
        if (params.serverType == 'amaderftp') {
          return await _buildAmaderFtpDetails(ref, params);
        }

        if (params.initialData != null) {
          if (params.serverType == 'circleftp') {
            return ContentDetails.fromCircleFtp(
              params.initialData!,
              'http://new.circleftp.net:5000/uploads/',
              params.serverName,
            );
          } else if (params.serverType == 'dflix') {
            return ContentDetails.fromDflix(
              params.initialData!,
              'http://www.dflix.live/Admin/main/images',
              params.serverName,
            );
          }
        }

        final api = ref.watch(contentDetailsApiProvider);
        final workingServers = await ref.watch(
          workingFtpServersProvider.future,
        );

        final server = workingServers.firstWhere(
          (s) => s.name == params.serverName,
          orElse: () => throw Exception('Server not found'),
        );

        final baseUrl = _extractBaseUrl(server, params.serverType);

        if (baseUrl == null) {
          throw Exception('Could not determine base URL for server');
        }

        if (params.serverType == 'circleftp') {
          final data = await api.getCircleFtpDetails(baseUrl, params.contentId);
          return ContentDetails.fromCircleFtp(
            data,
            '$baseUrl/uploads/',
            params.serverName,
          );
        } else if (params.serverType == 'dflix') {
          if (params.initialData == null) {
            throw Exception('Dflix requires initial data for details');
          }
          return ContentDetails.fromDflix(
            params.initialData!,
            'http://www.dflix.live/Admin/main/images',
            params.serverName,
          );
        }

        throw Exception('Unknown server type: ${params.serverType}');
      } catch (e, stackTrace) {
        _logger.e(
          'Error in ContentDetailsProvider: $e\nStackTrace: $stackTrace',
        );
        rethrow;
      }
    });

Future<ContentDetails> _buildAmaderFtpDetails(
  Ref ref,
  ({
    String contentId,
    String serverName,
    String serverType,
    Map<String, dynamic>? initialData,
  })
  params,
) async {
  const baseUrl = 'http://amaderftp.net:8096';

  try {
    final sessionNotifier = ref.read(amaderFtpSessionProvider.notifier);
    await sessionNotifier.ensureAuthenticated();

    final sessionState = ref.read(amaderFtpSessionProvider);
    final accessToken = sessionState.session?.accessToken;

    final api = sessionNotifier.getAuthenticatedApi();
    if (api == null) {
      throw Exception('AmaderFTP authentication failed');
    }

    Map<String, dynamic> itemData;
    if (params.initialData != null && params.initialData!.containsKey('Id')) {
      try {
        itemData = await api.getItemDetails(params.contentId);
      } catch (e) {
        itemData = params.initialData!;
      }
    } else {
      itemData = await api.getItemDetails(params.contentId);
    }

    var details = ContentDetails.fromAmaderFtp(
      itemData,
      baseUrl,
      params.serverName,
      accessToken,
    );

    if (details.contentType == 'series') {
      final seasons = await _fetchAmaderFtpSeasons(
        api,
        params.contentId,
        baseUrl,
        accessToken,
      );
      details = details.copyWithSeasons(seasons);
    }

    return details;
  } catch (e, stackTrace) {
    _logger.e('Error in _buildAmaderFtpDetails: $e\nStackTrace: $stackTrace');
    rethrow;
  }
}

Future<List<Season>> _fetchAmaderFtpSeasons(
  dynamic api,
  String seriesId,
  String baseUrl,
  String? accessToken,
) async {
  final seasons = <Season>[];

  try {
    final seasonsData = await api.getSeriesSeasons(seriesId);

    for (final seasonData in seasonsData) {
      final seasonId = seasonData['Id']?.toString();
      if (seasonId == null) continue;

      final episodesData = await api.getSeriesEpisodes(
        seriesId,
        seasonId: seasonId,
      );

      final episodes = <Episode>[];

      for (final epData in episodesData) {
        episodes.add(
          Episode.fromAmaderFtp(
            epData as Map<String, dynamic>,
            baseUrl,
            accessToken,
          ),
        );
      }

      seasons.add(
        Season.fromAmaderFtp(seasonData as Map<String, dynamic>, episodes),
      );
    }
  } catch (e) {
    _logger.e('Error fetching seasons/episodes: $e');
    return [];
  }

  return seasons;
}

String? _extractBaseUrl(dynamic server, String serverType) {
  if (serverType == 'circleftp') {
    return 'http://new.circleftp.net:5000';
  } else if (serverType == 'dflix') {
    return 'http://www.dflix.live';
  } else if (serverType == 'amaderftp') {
    return 'http://amaderftp.net:8096';
  }

  if (server.pingUrl != null && server.pingUrl!.isNotEmpty) {
    final uri = Uri.tryParse(server.pingUrl!);
    if (uri != null) {
      final port = uri.hasPort && uri.port != 80 && uri.port != 443
          ? ':${uri.port}'
          : '';
      return '${uri.scheme}://${uri.host}$port';
    }
  }

  return null;
}

final contentDetailsWithHistoryProvider = FutureProvider.family
    .autoDispose<
      ({
        ContentDetails details,
        WatchHistory? watchHistory,
        Duration? initialPosition,
      }),
      ({
        String contentId,
        String serverName,
        String serverType,
        String ftpServerId,
        Map<String, dynamic>? initialData,
        int? initialSeasonNumber,
        int? initialEpisodeNumber,
      })
    >((ref, params) async {
      final details = await ref.watch(
        contentDetailsProvider((
          contentId: params.contentId,
          serverName: params.serverName,
          serverType: params.serverType,
          initialData: params.initialData,
        )).future,
      );

      final storage = ref.read(watchHistoryStorageProvider);
      final watchHistory = await storage.getWatchHistory(
        ftpServerId: params.ftpServerId,
        contentId: params.contentId,
      );

      Duration? initialPosition;

      if (params.initialSeasonNumber != null &&
          params.initialEpisodeNumber != null &&
          watchHistory?.seriesProgress != null) {
        try {
          final seasonProgress = watchHistory!.seriesProgress!.firstWhere(
            (s) => s.seasonNumber == params.initialSeasonNumber,
          );

          final episodeProgress = seasonProgress.episodes.firstWhere(
            (e) => e.episodeNumber == params.initialEpisodeNumber,
          );

          final progress = episodeProgress.progress;
          if (progress.currentTime > 0 && progress.duration > 0) {
            final percentage = (progress.currentTime / progress.duration) * 100;
            if (percentage < 95) {
              initialPosition = Duration(seconds: progress.currentTime.toInt());
            }
          }
        } catch (e) {
          _logger.w('Error calculating initial position: $e');
        }
      } else if (watchHistory?.seriesProgress != null &&
          watchHistory!.seriesProgress!.isNotEmpty) {
        EpisodeProgress? lastWatchedEpisode;

        for (final seasonProgress in watchHistory.seriesProgress!) {
          for (final episodeProgress in seasonProgress.episodes) {
            if (lastWatchedEpisode == null ||
                episodeProgress.lastWatchedAt.isAfter(
                  lastWatchedEpisode.lastWatchedAt,
                )) {
              lastWatchedEpisode = episodeProgress;
            }
          }
        }

        if (lastWatchedEpisode != null) {
          final progress = lastWatchedEpisode.progress;
          if (progress.currentTime > 0 && progress.duration > 0) {
            final percentage = (progress.currentTime / progress.duration) * 100;
            if (percentage < 95) {
              initialPosition = Duration(seconds: progress.currentTime.toInt());
            }
          }
        }
      } else if (!details.isSeries && watchHistory?.progress != null) {
        final progress = watchHistory!.progress!;
        if (progress.currentTime > 0 && progress.duration > 0) {
          final percentage = (progress.currentTime / progress.duration) * 100;
          if (percentage < 95) {
            initialPosition = Duration(seconds: progress.currentTime.toInt());
          }
        }
      }

      return (
        details: details,
        watchHistory: watchHistory,
        initialPosition: initialPosition,
      );
    });
