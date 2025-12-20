import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/ftp_servers/data/ftp_server_repository.dart';

final workingFtpServersProvider =
    FutureProvider.autoDispose<List<FtpServerDto>>((ref) async {
      ref.watch(workingFtpServersRefreshProvider);
      final repo = ref.read(ftpServerRepositoryProvider);
      return repo.getWorkingServers();
    });

final workingFtpServersRefreshProvider = StateProvider<int>((ref) => 0);
