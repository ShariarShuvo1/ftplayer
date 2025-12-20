import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/ftp_servers/data/ftp_server_models.dart';
import '../../features/ftp_servers/data/ftp_server_repository.dart';

final allFtpServersProvider = FutureProvider.autoDispose<List<FtpServerDto>>((
  ref,
) async {
  ref.watch(allFtpServersRefreshProvider);
  final repo = ref.read(ftpServerRepositoryProvider);
  return repo.getAllServers();
});

final allFtpServersRefreshProvider = StateProvider<int>((ref) => 0);
