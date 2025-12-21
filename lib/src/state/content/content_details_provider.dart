import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../features/content_details/data/content_details_api.dart';
import '../../features/content_details/data/content_details_models.dart';
import '../ftp/working_ftp_servers_provider.dart';

final contentDetailsApiProvider = Provider<ContentDetailsApi>((ref) {
  final dio = ref.watch(dioProvider);
  return ContentDetailsApi(dio);
});

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
      final workingServers = await ref.watch(workingFtpServersProvider.future);

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
    });

String? _extractBaseUrl(dynamic server, String serverType) {
  if (serverType == 'circleftp') {
    return 'http://new.circleftp.net:5000';
  } else if (serverType == 'dflix') {
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
