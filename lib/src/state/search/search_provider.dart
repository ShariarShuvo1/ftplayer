import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/home/data/circleftp_api.dart';
import '../../features/home/data/dflix_api.dart';
import '../../features/search/data/search_models.dart';
import '../ftp/public_ftp_servers_provider.dart';
import '../ftp/working_ftp_servers_provider.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<SearchResultsData>((
  ref,
) async {
  final query = ref.watch(searchQueryProvider);

  if (query.trim().isEmpty) {
    return SearchResultsData.empty('');
  }

  final workingServersAsync = ref.watch(workingFtpServersProvider);

  return workingServersAsync.when(
    data: (workingServers) async {
      var servers = workingServers;

      if (servers.isEmpty) {
        final publicServersAsync = await ref.read(
          publicFtpServersProvider.future,
        );
        servers = publicServersAsync;
      }

      if (servers.isEmpty) {
        return SearchResultsData.empty(query);
      }

      final results = <SearchResult>[];
      final dio = Dio();

      for (final server in servers) {
        if (!server.isActive) continue;

        try {
          if (server.serverType == 'circleftp') {
            final serverResults = await _searchCircleFtp(dio, server, query);
            results.addAll(serverResults);
          } else if (server.serverType == 'dflix') {
            final serverResults = await _searchDflix(dio, server, query);
            results.addAll(serverResults);
          }
        } catch (_) {
          continue;
        }
      }

      final filteredResults = results.where((r) => r.isMovieOrSeries).toList();

      return SearchResultsData(results: filteredResults, query: query);
    },
    loading: () => SearchResultsData.empty(query),
    error: (_, _) => SearchResultsData.empty(query),
  );
});

Future<List<SearchResult>> _searchCircleFtp(
  Dio dio,
  FtpServerDto server,
  String query,
) async {
  final baseUrl = _extractBaseUrl(server);
  if (baseUrl == null) return [];

  final api = CircleFtpApi(dio, baseUrl);
  final imageBaseUrl = '$baseUrl/uploads/';

  final data = await api.searchContent(query);
  final results = <SearchResult>[];

  for (final item in data) {
    final result = SearchResult.fromCircleFtp(
      item as Map<String, dynamic>,
      imageBaseUrl,
      server.name,
    );
    results.add(result);
  }

  return results;
}

Future<List<SearchResult>> _searchDflix(
  Dio dio,
  FtpServerDto server,
  String query,
) async {
  final baseUrl = _extractBaseUrl(server);
  if (baseUrl == null) return [];

  final api = DflixApi(dio, baseUrl);
  final imageBaseUrl = '$baseUrl/Admin/main/images';

  final data = await api.searchContent(query);
  final results = <SearchResult>[];

  for (final item in data) {
    final result = SearchResult.fromDflix(
      item as Map<String, dynamic>,
      imageBaseUrl,
      server.name,
    );
    results.add(result);
  }

  return results;
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
