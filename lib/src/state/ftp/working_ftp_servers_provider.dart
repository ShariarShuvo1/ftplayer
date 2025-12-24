import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/ftp_servers/data/ftp_server_repository.dart';
import '../connectivity/connectivity_provider.dart';

final workingFtpServersProvider =
    FutureProvider.autoDispose<List<FtpServerDto>>((ref) async {
      ref.watch(workingFtpServersRefreshProvider);
      final isOffline = ref.watch(offlineModeProvider);
      final repo = ref.read(ftpServerRepositoryProvider);

      if (isOffline) {
        try {
          return await repo.getWorkingServers();
        } catch (_) {
          return [];
        }
      }

      return repo.getWorkingServers();
    });

final workingFtpServersRefreshProvider = StateProvider<int>((ref) => 0);
