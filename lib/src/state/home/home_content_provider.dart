import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../amaderftp/amaderftp_session_provider.dart';
import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/home/data/circleftp_api.dart';
import '../../features/home/data/dflix_api.dart';
import '../../features/home/data/home_models.dart';
import '../ftp/public_ftp_servers_provider.dart';
import '../ftp/working_ftp_servers_provider.dart';

final homeContentProvider = FutureProvider.autoDispose<HomeContentData>((
  ref,
) async {
  final workingServersFuture = ref.watch(workingFtpServersProvider.future);

  var servers = await workingServersFuture;

  if (servers.isEmpty) {
    final publicServersAsync = await ref.read(publicFtpServersProvider.future);
    servers = publicServersAsync;
  }

  if (servers.isEmpty) {
    return HomeContentData.empty();
  }

  final serverMovies = <List<ContentItem>>[];
  final serverSeries = <List<ContentItem>>[];
  final trendingItems = <ContentItem>[];

  final dio = Dio();

  for (final server in servers) {
    if (!server.isActive) {
      continue;
    }

    try {
      if (server.serverType == 'circleftp') {
        final result = await _fetchCircleFtpContent(dio, server);
        serverMovies.add(result.movies);
        serverSeries.add(result.series);
        trendingItems.addAll(result.trending);
      } else if (server.serverType == 'dflix') {
        final result = await _fetchDflixContent(dio, server);
        serverMovies.add(result.movies);
        serverSeries.add(result.series);
      } else if (server.serverType == 'amaderftp') {
        final result = await _fetchAmaderFtpContent(ref, server);
        serverMovies.add(result.movies);
        serverSeries.add(result.series);
        trendingItems.addAll(result.trending);
      }
    } catch (e) {
      debugPrint(
        '❌ [HomeContentProvider] Error fetching content from ${server.serverType} server ${server.name}: $e',
      );
      continue;
    }
  }

  final featured = _interleaveContent(serverMovies, 15);
  final latest = _interleaveContent(serverMovies, 30);
  final tvSeries = _interleaveContent(serverSeries, 30);
  final serverTrending = _groupTrendingByServer(trendingItems);
  final trending = _interleaveContent(serverTrending, 30);

  return HomeContentData(
    featured: featured,
    trending: trending,
    latest: latest,
    tvSeries: tvSeries,
  );
});

Future<_ServerContentResult> _fetchCircleFtpContent(
  Dio dio,
  FtpServerDto server,
) async {
  final movies = <ContentItem>[];
  final series = <ContentItem>[];
  final trending = <ContentItem>[];

  final baseUrl = _extractBaseUrl(server);

  if (baseUrl == null) {
    return _ServerContentResult(movies, series, trending);
  }

  final api = CircleFtpApi(dio, baseUrl);
  final imageBaseUrl = '$baseUrl/uploads/';

  try {
    final homeData = await api.getHomePage();

    final categoryPosts = homeData['categoryPosts'] as List<dynamic>?;

    if (categoryPosts != null && categoryPosts.isNotEmpty) {
      final movieCategories = [
        'English Movies',
        'Hindi Movies',
        'Foreign Language Movies',
        'English & Foreign Hindi Dubbed Movies',
        'South Indian Movies',
        'South Indian Dubbed Movie',
        'Animation Movies',
        'Animation Dubbed Movies',
        'Documentary',
      ];

      final tvCategories = [
        'English & Foreign TV Series',
        'Dubbed TV Series & Shows',
        'Hindi TV Serials',
        'English & Foreign Anime Series',
      ];

      for (final category in categoryPosts) {
        final categoryMap = category as Map<String, dynamic>;
        final categoryName = categoryMap['name']?.toString() ?? '';
        final posts = categoryMap['posts'] as List<dynamic>?;

        if (posts == null || posts.isEmpty) continue;

        if (movieCategories.contains(categoryName)) {
          for (final item in posts.take(30)) {
            final itemMap = item as Map<String, dynamic>;
            final type = itemMap['type']?.toString();

            if (type == 'singleVideo') {
              final contentItem = ContentItem.fromCircleFtp(
                itemMap,
                imageBaseUrl,
                server.name,
              );
              movies.add(contentItem);
            }
          }
        } else if (tvCategories.contains(categoryName)) {
          for (final item in posts.take(30)) {
            final itemMap = item as Map<String, dynamic>;
            final type = itemMap['type']?.toString();

            if (type == 'series') {
              final contentItem = ContentItem.fromCircleFtp(
                itemMap,
                imageBaseUrl,
                server.name,
              );
              series.add(contentItem);
            }
          }
        }
      }
    }

    final mostVisitedPosts = homeData['mostVisitedPosts'] as List<dynamic>?;

    if (mostVisitedPosts != null) {
      for (final item in mostVisitedPosts.take(30)) {
        final itemMap = item as Map<String, dynamic>;
        final type = itemMap['type']?.toString();

        if (type == 'singleVideo' || type == 'series') {
          final contentItem = ContentItem.fromCircleFtp(
            itemMap,
            imageBaseUrl,
            server.name,
          );
          trending.add(contentItem);
        }
      }
    }
  } catch (e) {
    return _ServerContentResult(movies, series, trending);
  }

  return _ServerContentResult(movies, series, trending);
}

Future<_ServerContentResult> _fetchDflixContent(
  Dio dio,
  FtpServerDto server,
) async {
  final movies = <ContentItem>[];
  final series = <ContentItem>[];
  final trending = <ContentItem>[];

  final baseUrl = _extractBaseUrl(server);

  if (baseUrl == null) {
    return _ServerContentResult(movies, series, trending);
  }

  final api = DflixApi(dio, baseUrl);
  final imageBaseUrl = '$baseUrl/Admin/main/images';

  try {
    final moviesList = await api.getMovies(limit: 30);
    for (final movie in moviesList) {
      final contentItem = ContentItem.fromDflix(
        movie as Map<String, dynamic>,
        imageBaseUrl,
        server.name,
      );
      movies.add(contentItem);
    }

    final showsList = await api.getTvShows(limit: 30);
    for (final show in showsList) {
      final contentItem = ContentItem.fromDflix(
        show as Map<String, dynamic>,
        imageBaseUrl,
        server.name,
      );
      series.add(contentItem);
    }
  } catch (e) {
    return _ServerContentResult(movies, series, trending);
  }

  return _ServerContentResult(movies, series, trending);
}

Future<_ServerContentResult> _fetchAmaderFtpContent(
  Ref ref,
  FtpServerDto server,
) async {
  final movies = <ContentItem>[];
  final series = <ContentItem>[];
  final trending = <ContentItem>[];

  const baseUrl = 'http://amaderftp.net:8096';

  final sessionNotifier = ref.read(amaderFtpSessionProvider.notifier);
  await sessionNotifier.ensureAuthenticated();

  final api = sessionNotifier.getAuthenticatedApi();
  if (api == null) {
    debugPrint('❌ [_fetchAmaderFtpContent] API is null after authentication!');
    return _ServerContentResult(movies, series, trending);
  }

  try {
    final moviesList = await api.getLatestMovies(limit: 25);
    for (final movie in moviesList.take(10)) {
      final movieMap = movie as Map<String, dynamic>;
      if (movieMap['Type'] == 'Movie') {
        try {
          final itemId = movieMap['Id']?.toString();
          if (itemId != null && itemId.isNotEmpty) {
            final detailedItem = await api.getItemDetails(itemId);
            final contentItem = ContentItem.fromAmaderFtp(
              detailedItem,
              baseUrl,
              server.name,
            );
            movies.add(contentItem);
          }
        } catch (e) {
          continue;
        }
      }
    }

    final showsList = await api.getLatestTvSeries(limit: 10);

    for (final show in showsList.take(10)) {
      final showMap = show as Map<String, dynamic>;
      if (showMap['Type'] == 'Series') {
        try {
          final itemId = showMap['Id']?.toString();
          if (itemId != null && itemId.isNotEmpty) {
            final detailedItem = await api.getItemDetails(itemId);
            final contentItem = ContentItem.fromAmaderFtp(
              detailedItem,
              baseUrl,
              server.name,
            );
            series.add(contentItem);
          }
        } catch (e) {
          continue;
        }
      }
    }

    trending.addAll(movies);
    trending.addAll(series);
  } catch (e) {
    debugPrint('❌ [_fetchAmaderFtpContent] Exception: $e');
    return _ServerContentResult(movies, series, trending);
  }

  return _ServerContentResult(movies, series, trending);
}

List<ContentItem> _interleaveContent(
  List<List<ContentItem>> serverContents,
  int limit,
) {
  if (serverContents.isEmpty) return [];

  final result = <ContentItem>[];
  int maxLength = 0;

  for (final items in serverContents) {
    if (items.length > maxLength) {
      maxLength = items.length;
    }
  }

  for (int i = 0; i < maxLength && result.length < limit; i++) {
    for (final items in serverContents) {
      if (i < items.length && result.length < limit) {
        result.add(items[i]);
      }
    }
  }

  return result;
}

class _ServerContentResult {
  _ServerContentResult(this.movies, this.series, this.trending);
  final List<ContentItem> movies;
  final List<ContentItem> series;
  final List<ContentItem> trending;
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

List<List<ContentItem>> _groupTrendingByServer(
  List<ContentItem> trendingItems,
) {
  final grouped = <String, List<ContentItem>>{};

  for (final item in trendingItems) {
    grouped.putIfAbsent(item.serverName, () => []).add(item);
  }

  return grouped.values.toList();
}
