import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/ftp_servers/data/ftp_servers_local_data.dart';

final allFtpServersProvider = FutureProvider.autoDispose<List<FtpServerDto>>((
  ref,
) async {
  ref.watch(allFtpServersRefreshProvider);
  return FtpServersLocalData.getAllServers();
});

final allFtpServersRefreshProvider = StateProvider<int>((ref) => 0);
