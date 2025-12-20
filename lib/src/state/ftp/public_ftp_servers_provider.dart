import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/ftp_servers/data/ftp_server_repository.dart';

final publicFtpServersProvider = FutureProvider.autoDispose<List<FtpServerDto>>(
  (ref) async {
    ref.watch(publicFtpServersRefreshProvider);
    final repo = ref.read(ftpServerRepositoryProvider);
    return repo.getAllPublicServers();
  },
);

final publicFtpServersRefreshProvider = StateProvider<int>((ref) => 0);
