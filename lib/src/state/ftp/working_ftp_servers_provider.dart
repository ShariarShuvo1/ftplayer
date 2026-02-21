import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/ftp_servers/data/ftp_servers_local_data.dart';
import '../../features/ftp_servers/data/working_servers_storage.dart';
import '../connectivity/connectivity_provider.dart';

final workingFtpServersProvider =
    FutureProvider.autoDispose<List<FtpServerDto>>((ref) async {
      ref.watch(workingFtpServersRefreshProvider);
      final isOffline = ref.watch(offlineModeProvider);

      if (isOffline) {
        return [];
      }

      try {
        final storage = ref.read(workingServersStorageProvider);
        final workingIds = await storage.getWorkingServerIds();
        final allServers = FtpServersLocalData.getAllServers();
        return allServers
            .where((server) => workingIds.contains(server.id))
            .toList();
      } catch (_) {
        return [];
      }
    });

final workingFtpServersRefreshProvider = StateProvider<int>((ref) => 0);
