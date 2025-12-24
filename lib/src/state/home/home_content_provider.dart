import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  final featured = <ContentItem>[];
  final trending = <ContentItem>[];
  final latest = <ContentItem>[];
  final tvSeries = <ContentItem>[];

  final dio = Dio();

  for (final server in servers) {
    if (!server.isActive) {
      continue;
    }

    try {
      if (server.serverType == 'circleftp') {
        await _fetchCircleFtpContent(
          dio,
          server,
          featured,
          trending,
          latest,
          tvSeries,
        );
      } else if (server.serverType == 'dflix') {
        await _fetchDflixContent(dio, server, featured, latest, tvSeries);
      }
    } catch (e) {
      continue;
    }
  }

  return HomeContentData(
    featured: featured.take(10).toList(),
    trending: trending.take(30).toList(),
    latest: latest.take(30).toList(),
    tvSeries: tvSeries.take(30).toList(),
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

  if (baseUrl == null) {
    return;
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
          for (final item in posts.take(3)) {
            final itemMap = item as Map<String, dynamic>;
            final type = itemMap['type']?.toString();

            if (type == 'singleVideo') {
              final contentItem = ContentItem.fromCircleFtp(
                itemMap,
                imageBaseUrl,
                server.name,
              );
              featured.add(contentItem);
              latest.add(contentItem);
            }
          }
        } else if (tvCategories.contains(categoryName)) {
          for (final item in posts.take(5)) {
            final itemMap = item as Map<String, dynamic>;
            final type = itemMap['type']?.toString();

            if (type == 'series') {
              final contentItem = ContentItem.fromCircleFtp(
                itemMap,
                imageBaseUrl,
                server.name,
              );
              tvSeries.add(contentItem);
            }
          }
        }
      }
    }

    final mostVisitedPosts = homeData['mostVisitedPosts'] as List<dynamic>?;

    if (mostVisitedPosts != null) {
      for (final item in mostVisitedPosts.take(20)) {
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

  if (baseUrl == null) {
    return;
  }

  final api = DflixApi(dio, baseUrl);
  final imageBaseUrl = '$baseUrl/Admin/main/images';

  try {
    final movies = await api.getMovies(limit: 30);
    for (final movie in movies) {
      final contentItem = ContentItem.fromDflix(
        movie as Map<String, dynamic>,
        imageBaseUrl,
        server.name,
      );
      if (featured.length < 15) {
        featured.add(contentItem);
      }
      latest.add(contentItem);
    }

    final shows = await api.getTvShows(limit: 30);
    for (final show in shows) {
      final contentItem = ContentItem.fromDflix(
        show as Map<String, dynamic>,
        imageBaseUrl,
        server.name,
      );
      tvSeries.add(contentItem);
    }
  } catch (e) {
    return;
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
