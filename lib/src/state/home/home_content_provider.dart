import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../amaderftp/amaderftp_session_provider.dart';
import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/home/data/circleftp_api.dart';
import '../../features/home/data/dflix_api.dart';
import '../../features/home/data/home_models.dart';
import '../ftp/public_ftp_servers_provider.dart';
import '../ftp/enabled_servers_provider.dart';
import '../ftp/working_ftp_servers_provider.dart';
import '../connectivity/connectivity_provider.dart';
import '../settings/home_content_settings_provider.dart';

final _logger = Logger();

final homeContentProvider = FutureProvider.autoDispose<HomeContentData>((
  ref,
) async {
  final isOffline = ref.watch(offlineModeProvider);

  if (isOffline) {
    return HomeContentData.empty();
  }

  final contentSettings = ref.watch(homeContentSettingsProvider);
  final filteredServersFuture = ref.watch(
    filteredWorkingServersProvider.future,
  );
  final workingServersFuture = ref.watch(workingFtpServersProvider.future);

  var servers = await filteredServersFuture;
  final workingServers = await workingServersFuture;

  if (servers.isEmpty && workingServers.isNotEmpty) {
    throw Exception('NO_ENABLED_SERVERS');
  }

  if (servers.isEmpty) {
    final publicServersAsync = await ref.read(publicFtpServersProvider.future);
    servers = publicServersAsync;
  }

  if (servers.isEmpty) {
    return HomeContentData.empty();
  }

  final featuredItems = <ContentItem>[];
  final latestItems = <ContentItem>[];
  final trendingItems = <ContentItem>[];
  final tvSeriesItems = <ContentItem>[];

  final dio = Dio();

  for (final server in servers) {
    if (!server.isActive) {
      continue;
    }

    try {
      if (server.serverType == 'circleftp') {
        final result = await _fetchCircleFtpContent(
          dio,
          server,
          contentSettings,
        );
        featuredItems.addAll(result.featured);
        latestItems.addAll(result.latest);
        trendingItems.addAll(result.trending);
        tvSeriesItems.addAll(result.tvSeries);
      } else if (server.serverType == 'dflix') {
        final result = await _fetchDflixContent(dio, server, contentSettings);
        featuredItems.addAll(result.featured);
        latestItems.addAll(result.latest);
        tvSeriesItems.addAll(result.tvSeries);
      } else if (server.serverType == 'amaderftp') {
        final result = await _fetchAmaderFtpContent(
          ref,
          server,
          contentSettings,
        );
        featuredItems.addAll(result.featured);
        latestItems.addAll(result.latest);
        trendingItems.addAll(result.trending);
        tvSeriesItems.addAll(result.tvSeries);
      }
    } catch (e) {
      _logger.e(
        'Error fetching content from ${server.serverType} server ${server.name}: $e',
      );
      continue;
    }
  }

  final random = _getRandomInstance();
  featuredItems.shuffle(random);
  latestItems.shuffle(random);
  trendingItems.shuffle(random);
  tvSeriesItems.shuffle(random);

  return HomeContentData(
    featured: featuredItems,
    trending: trendingItems,
    latest: latestItems,
    tvSeries: tvSeriesItems,
  );
});

Future<_ServerContentResult> _fetchCircleFtpContent(
  Dio dio,
  FtpServerDto server,
  HomeContentSettings settings,
) async {
  final featured = <ContentItem>[];
  final latest = <ContentItem>[];
  final trending = <ContentItem>[];
  final tvSeries = <ContentItem>[];

  final baseUrl = _extractBaseUrl(server);

  if (baseUrl == null) {
    return _ServerContentResult(featured, latest, trending, tvSeries);
  }

  final api = CircleFtpApi(dio, baseUrl);
  final imageBaseUrl = '$baseUrl/uploads/';

  try {
    if (settings.featuredCircleFtp > 0) {
      final posts = await api.browseByCategory(
        '6',
        limit: settings.featuredCircleFtp,
      );
      for (final item in posts) {
        final itemMap = item as Map<String, dynamic>;
        final type = itemMap['type']?.toString();
        if (type == 'singleVideo') {
          featured.add(
            ContentItem.fromCircleFtp(itemMap, imageBaseUrl, server.name),
          );
        }
      }
    }

    if (settings.latestCircleFtp > 0) {
      final posts = await api.browseByCategory(
        '6, 260',
        limit: settings.latestCircleFtp,
      );
      for (final item in posts) {
        final itemMap = item as Map<String, dynamic>;
        final type = itemMap['type']?.toString();
        if (type == 'singleVideo') {
          latest.add(
            ContentItem.fromCircleFtp(itemMap, imageBaseUrl, server.name),
          );
        }
      }
    }

    if (settings.trendingCircleFtp > 0) {
      final homeData = await api.getHomePage();
      final mostVisitedPosts = homeData['mostVisitedPosts'] as List<dynamic>?;
      if (mostVisitedPosts != null) {
        for (final item in mostVisitedPosts.take(settings.trendingCircleFtp)) {
          final itemMap = item as Map<String, dynamic>;
          final type = itemMap['type']?.toString();
          if (type == 'singleVideo' || type == 'series') {
            trending.add(
              ContentItem.fromCircleFtp(itemMap, imageBaseUrl, server.name),
            );
          }
        }
      }
    }

    if (settings.tvSeriesCircleFtp > 0) {
      final posts = await api.browseByCategory(
        '9',
        limit: settings.tvSeriesCircleFtp,
      );
      for (final item in posts) {
        final itemMap = item as Map<String, dynamic>;
        final type = itemMap['type']?.toString();
        if (type == 'series') {
          tvSeries.add(
            ContentItem.fromCircleFtp(itemMap, imageBaseUrl, server.name),
          );
        }
      }
    }
  } catch (e) {
    return _ServerContentResult(featured, latest, trending, tvSeries);
  }

  return _ServerContentResult(featured, latest, trending, tvSeries);
}

Future<_ServerContentResult> _fetchDflixContent(
  Dio dio,
  FtpServerDto server,
  HomeContentSettings settings,
) async {
  final featured = <ContentItem>[];
  final latest = <ContentItem>[];
  final trending = <ContentItem>[];
  final tvSeries = <ContentItem>[];

  final baseUrl = _extractBaseUrl(server);

  if (baseUrl == null) {
    return _ServerContentResult(featured, latest, trending, tvSeries);
  }

  final api = DflixApi(dio, baseUrl);
  final imageBaseUrl = '$baseUrl/Admin/main/images';

  try {
    if (settings.featuredDflix > 0) {
      final moviesList = await api.getMoviesByCategory(
        category: 'Hollywood',
        limit: settings.featuredDflix,
      );
      for (final movie in moviesList) {
        featured.add(
          ContentItem.fromDflix(
            movie as Map<String, dynamic>,
            imageBaseUrl,
            server.name,
          ),
        );
      }
    }

    if (settings.latestDflix > 0) {
      final moviesList = await api.getMovies(limit: settings.latestDflix);
      for (final movie in moviesList) {
        latest.add(
          ContentItem.fromDflix(
            movie as Map<String, dynamic>,
            imageBaseUrl,
            server.name,
          ),
        );
      }
    }

    if (settings.tvSeriesDflix > 0) {
      final showsList = await api.getTvShows(limit: settings.tvSeriesDflix);
      for (final show in showsList) {
        tvSeries.add(
          ContentItem.fromDflix(
            show as Map<String, dynamic>,
            imageBaseUrl,
            server.name,
          ),
        );
      }
    }
  } catch (e) {
    return _ServerContentResult(featured, latest, trending, tvSeries);
  }

  return _ServerContentResult(featured, latest, trending, tvSeries);
}

Future<_ServerContentResult> _fetchAmaderFtpContent(
  Ref ref,
  FtpServerDto server,
  HomeContentSettings settings,
) async {
  final featured = <ContentItem>[];
  final latest = <ContentItem>[];
  final trending = <ContentItem>[];
  final tvSeries = <ContentItem>[];

  const baseUrl = 'http://amaderftp.net:8096';

  final sessionNotifier = ref.read(amaderFtpSessionProvider.notifier);
  await sessionNotifier.ensureAuthenticated();

  final api = sessionNotifier.getAuthenticatedApi();
  if (api == null) {
    _logger.e('API is null after authentication in _fetchAmaderFtpContent');
    return _ServerContentResult(featured, latest, trending, tvSeries);
  }

  try {
    if (settings.featuredAmaderFtp > 0) {
      final moviesList = await api.getLatestMovies(
        limit: settings.featuredAmaderFtp,
      );
      for (final movie in moviesList.take(settings.featuredAmaderFtp)) {
        final movieMap = movie as Map<String, dynamic>;
        if (movieMap['Type'] == 'Movie') {
          try {
            final itemId = movieMap['Id']?.toString();
            if (itemId != null && itemId.isNotEmpty) {
              final detailedItem = await api.getItemDetails(itemId);
              featured.add(
                ContentItem.fromAmaderFtp(detailedItem, baseUrl, server.name),
              );
            }
          } catch (e) {
            continue;
          }
        }
      }
    }

    if (settings.latestAmaderFtp > 0) {
      final moviesList = await api.getLatestMovies(
        limit: settings.latestAmaderFtp,
      );
      for (final movie in moviesList.take(settings.latestAmaderFtp)) {
        final movieMap = movie as Map<String, dynamic>;
        if (movieMap['Type'] == 'Movie') {
          try {
            final itemId = movieMap['Id']?.toString();
            if (itemId != null && itemId.isNotEmpty) {
              final detailedItem = await api.getItemDetails(itemId);
              latest.add(
                ContentItem.fromAmaderFtp(detailedItem, baseUrl, server.name),
              );
            }
          } catch (e) {
            continue;
          }
        }
      }
    }

    if (settings.trendingAmaderFtp > 0) {
      final moviesList = await api.getLatestMovies(
        limit: settings.trendingAmaderFtp,
      );
      for (final movie in moviesList.take(settings.trendingAmaderFtp)) {
        final movieMap = movie as Map<String, dynamic>;
        if (movieMap['Type'] == 'Movie') {
          try {
            final itemId = movieMap['Id']?.toString();
            if (itemId != null && itemId.isNotEmpty) {
              final detailedItem = await api.getItemDetails(itemId);
              trending.add(
                ContentItem.fromAmaderFtp(detailedItem, baseUrl, server.name),
              );
            }
          } catch (e) {
            continue;
          }
        }
      }
    }

    if (settings.tvSeriesAmaderFtp > 0) {
      final showsList = await api.getLatestTvSeries(
        limit: settings.tvSeriesAmaderFtp,
      );
      for (final show in showsList.take(settings.tvSeriesAmaderFtp)) {
        final showMap = show as Map<String, dynamic>;
        if (showMap['Type'] == 'Series') {
          try {
            final itemId = showMap['Id']?.toString();
            if (itemId != null && itemId.isNotEmpty) {
              final detailedItem = await api.getItemDetails(itemId);
              tvSeries.add(
                ContentItem.fromAmaderFtp(detailedItem, baseUrl, server.name),
              );
            }
          } catch (e) {
            continue;
          }
        }
      }
    }
  } catch (e) {
    _logger.e('Exception in _fetchAmaderFtpContent: $e');
    return _ServerContentResult(featured, latest, trending, tvSeries);
  }

  return _ServerContentResult(featured, latest, trending, tvSeries);
}

math.Random _getRandomInstance() => math.Random();

class _ServerContentResult {
  _ServerContentResult(
    this.featured,
    this.latest,
    this.trending,
    this.tvSeries,
  );
  final List<ContentItem> featured;
  final List<ContentItem> latest;
  final List<ContentItem> trending;
  final List<ContentItem> tvSeries;
}

String? _extractBaseUrl(FtpServerDto server) {
  if (server.serverType == 'circleftp') {
    return 'http://new.circleftp.net:5000';
  } else if (server.serverType == 'dflix') {
    return 'http://www.dflix.live';
  } else if (server.serverType == 'amaderftp') {
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
