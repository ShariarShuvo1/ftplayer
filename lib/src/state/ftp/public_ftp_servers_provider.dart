import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/ftp_servers/data/ftp_servers_local_data.dart';

final publicFtpServersProvider = FutureProvider.autoDispose<List<FtpServerDto>>(
  (ref) async {
    ref.watch(publicFtpServersRefreshProvider);
    return FtpServersLocalData.getPublicServers();
  },
);

final publicFtpServersRefreshProvider = StateProvider<int>((ref) => 0);
