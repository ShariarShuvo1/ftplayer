import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../amaderftp/amaderftp_session_provider.dart';
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

      final serverResults = <List<SearchResult>>[];
      final dio = Dio();

      for (final server in servers) {
        if (!server.isActive) continue;

        try {
          if (server.serverType == 'circleftp') {
            final results = await _searchCircleFtp(dio, server, query);
            serverResults.add(results);
          } else if (server.serverType == 'dflix') {
            final results = await _searchDflix(dio, server, query);
            serverResults.add(results);
          } else if (server.serverType == 'amaderftp') {
            final results = await _searchAmaderFtp(ref, server, query);
            serverResults.add(results);
          }
        } catch (_) {
          continue;
        }
      }

      final interleavedResults = _interleaveSearchResults(serverResults);
      final filteredResults = interleavedResults
          .where((r) => r.isMovieOrSeries)
          .toList();

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

Future<List<SearchResult>> _searchAmaderFtp(
  Ref ref,
  FtpServerDto server,
  String query,
) async {
  const baseUrl = 'http://amaderftp.net:8096';

  final sessionNotifier = ref.read(amaderFtpSessionProvider.notifier);
  await sessionNotifier.ensureAuthenticated();

  final api = sessionNotifier.getAuthenticatedApi();
  if (api == null) return [];

  final data = await api.searchContent(query);
  final results = <SearchResult>[];

  for (final item in data) {
    final result = SearchResult.fromAmaderFtp(
      item as Map<String, dynamic>,
      baseUrl,
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

List<SearchResult> _interleaveSearchResults(
  List<List<SearchResult>> serverResults,
) {
  if (serverResults.isEmpty) return [];

  final result = <SearchResult>[];
  int maxLength = 0;

  for (final items in serverResults) {
    if (items.length > maxLength) {
      maxLength = items.length;
    }
  }

  for (int i = 0; i < maxLength; i++) {
    for (final items in serverResults) {
      if (i < items.length) {
        result.add(items[i]);
      }
    }
  }

  return result;
}
