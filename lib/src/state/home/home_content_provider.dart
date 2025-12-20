import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/home/data/circleftp_api.dart';
import '../../features/home/data/dflix_api.dart';
import '../../features/home/data/home_models.dart';
import '../ftp/public_ftp_servers_provider.dart';
import '../ftp/working_ftp_servers_provider.dart';

final _logger = Logger();

final homeContentProvider = FutureProvider.autoDispose<HomeContentData>((
  ref,
) async {
  final workingServersAsync = ref.watch(workingFtpServersProvider);

  return workingServersAsync.when(
    data: (workingServers) async {
      var servers = workingServers;

      _logger.i('Working servers count: ${servers.length}');

      if (servers.isEmpty) {
        _logger.i('No working servers, fetching public servers...');
        final publicServersAsync = await ref.read(
          publicFtpServersProvider.future,
        );
        servers = publicServersAsync;
        _logger.i('Public servers count: ${servers.length}');
      }

      if (servers.isEmpty) {
        _logger.w('No servers available at all');
        return HomeContentData.empty();
      }

      final featured = <ContentItem>[];
      final trending = <ContentItem>[];
      final latest = <ContentItem>[];
      final tvSeries = <ContentItem>[];

      final dio = Dio();

      for (final server in servers) {
        _logger.i('Processing server: ${server.name} (${server.serverType})');

        if (!server.isActive) {
          _logger.w('Server ${server.name} is not active, skipping');
          continue;
        }

        try {
          if (server.serverType == 'circleftp') {
            _logger.i('Fetching CircleFTP content from ${server.name}...');
            await _fetchCircleFtpContent(
              dio,
              server,
              featured,
              trending,
              latest,
              tvSeries,
            );
            _logger.i(
              'CircleFTP fetch complete. Featured: ${featured.length}, Trending: ${trending.length}, Latest: ${latest.length}, TV: ${tvSeries.length}',
            );
          } else if (server.serverType == 'dflix') {
            _logger.i('Fetching Dflix content from ${server.name}...');
            await _fetchDflixContent(dio, server, featured, latest, tvSeries);
            _logger.i(
              'Dflix fetch complete. Featured: ${featured.length}, Latest: ${latest.length}, TV: ${tvSeries.length}',
            );
          }
        } catch (e) {
          _logger.e('Error fetching from ${server.name}: $e');
          continue;
        }
      }

      _logger.i(
        'Total content fetched - Featured: ${featured.length}, Trending: ${trending.length}, Latest: ${latest.length}, TV Series: ${tvSeries.length}',
      );

      return HomeContentData(
        featured: featured.take(10).toList(),
        trending: trending.take(20).toList(),
        latest: latest.take(20).toList(),
        tvSeries: tvSeries.take(20).toList(),
      );
    },
    loading: () => HomeContentData.empty(),
    error: (_, _) => HomeContentData.empty(),
  );
});

Future<void> _fetchCircleFtpContent(
  Dio dio,
  FtpServerDto server,
  List<ContentItem> featured,
  List<ContentItem> trending,
  List<ContentItem> latest,
  List<ContentItem> tvSeries,
) async {
  final baseUrl = _extractBaseUrl(server);
  _logger.d('CircleFTP base URL: $baseUrl');

  if (baseUrl == null) {
    _logger.w('CircleFTP base URL is null for ${server.name}');
    return;
  }

  final api = CircleFtpApi(dio, baseUrl);
  final imageBaseUrl = '$baseUrl/uploads/';

  try {
    _logger.d('Calling CircleFTP getHomePage API...');
    final homeData = await api.getHomePage();
    _logger.d('CircleFTP API response received: ${homeData.keys}');

    final categoryPosts = homeData['categoryPosts'] as List<dynamic>?;
    _logger.d('categoryPosts count: ${categoryPosts?.length ?? 0}');

    if (categoryPosts != null && categoryPosts.isNotEmpty) {
      final firstCategory = categoryPosts.first as Map<String, dynamic>;
      final posts = firstCategory['posts'] as List<dynamic>?;
      _logger.d('First category posts count: ${posts?.length ?? 0}');

      if (posts != null) {
        for (final item in posts.take(5)) {
          try {
            final contentItem = ContentItem.fromCircleFtp(
              item as Map<String, dynamic>,
              imageBaseUrl,
              server.name,
            );
            featured.add(contentItem);
          } catch (e) {
            _logger.e('Error parsing featured item: $e');
          }
        }
      }
    }

    final mostVisitedPosts = homeData['mostVisitedPosts'] as List<dynamic>?;
    _logger.d('mostVisitedPosts count: ${mostVisitedPosts?.length ?? 0}');

    if (mostVisitedPosts != null) {
      for (final item in mostVisitedPosts.take(10)) {
        try {
          final contentItem = ContentItem.fromCircleFtp(
            item as Map<String, dynamic>,
            imageBaseUrl,
            server.name,
          );
          trending.add(contentItem);
        } catch (e) {
          _logger.e('Error parsing trending item: $e');
        }
      }
    }

    final latestPost = homeData['latestPost'] as List<dynamic>?;
    _logger.d('latestPost count: ${latestPost?.length ?? 0}');

    if (latestPost != null) {
      for (final item in latestPost.take(10)) {
        try {
          final contentItem = ContentItem.fromCircleFtp(
            item as Map<String, dynamic>,
            imageBaseUrl,
            server.name,
          );

          if (contentItem.contentType == 'series') {
            tvSeries.add(contentItem);
          } else {
            latest.add(contentItem);
          }
        } catch (e) {
          _logger.e('Error parsing latest item: $e');
        }
      }
    }
  } catch (e) {
    _logger.e('Error fetching CircleFTP content: $e');
    return;
  }
}

Future<void> _fetchDflixContent(
  Dio dio,
  FtpServerDto server,
  List<ContentItem> featured,
  List<ContentItem> latest,
  List<ContentItem> tvSeries,
) async {
  final baseUrl = _extractBaseUrl(server);
  _logger.d('Dflix base URL: $baseUrl');

  if (baseUrl == null) {
    _logger.w('Dflix base URL is null for ${server.name}');
    return;
  }

  final api = DflixApi(dio, baseUrl);
  final imageBaseUrl = '$baseUrl/Admin/main/images';

  try {
    _logger.d('Calling Dflix getMovies API...');
    final movies = await api.getMovies(limit: 10);
    _logger.d('Dflix movies count: ${movies.length}');

    for (final movie in movies.take(5)) {
      try {
        final contentItem = ContentItem.fromDflix(
          movie as Map<String, dynamic>,
          imageBaseUrl,
          server.name,
        );
        featured.add(contentItem);
        latest.add(contentItem);
      } catch (e) {
        _logger.e('Error parsing Dflix movie: $e');
      }
    }
  } catch (e) {
    _logger.e('Error fetching Dflix movies: $e');
  }

  try {
    _logger.d('Calling Dflix getTvShows API...');
    final shows = await api.getTvShows(limit: 10);
    _logger.d('Dflix TV shows count: ${shows.length}');

    for (final show in shows) {
      try {
        final contentItem = ContentItem.fromDflix(
          show as Map<String, dynamic>,
          imageBaseUrl,
          server.name,
        );
        tvSeries.add(contentItem);
      } catch (e) {
        _logger.e('Error parsing Dflix TV show: $e');
      }
    }
  } catch (e) {
    _logger.e('Error fetching Dflix TV shows: $e');
  }
}

String? _extractBaseUrl(FtpServerDto server) {
  if (server.serverType == 'circleftp') {
    return 'http://new.circleftp.net:5000';
  } else if (server.serverType == 'dflix') {
    return 'http://www.dflix.live';
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
