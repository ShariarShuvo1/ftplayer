import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_provider.dart';
import 'ftp_server_api.dart';
import 'ftp_server_models.dart';

final ftpServerRepositoryProvider = Provider<FtpServerRepository>((ref) {
  final dio = ref.read(dioProvider);
  return FtpServerRepository(api: FtpServerApi(dio));
});

class FtpServerRepository {
  FtpServerRepository({required this.api});

  final FtpServerApi api;

  Future<List<FtpServerDto>> getAllServers() async {
    final res = await api.getAllServers();
    return res.servers;
  }

  Future<List<FtpServerDto>> getAllPublicServers() async {
    final res = await api.getAllPublicServers();
    return res.servers;
  }

  Future<List<FtpServerDto>> getWorkingServers() async {
    final res = await api.getWorkingServers();
    return res.servers;
  }

  Future<List<FtpServerDto>> updateWorkingServers({
    required List<String> ftpServerIds,
  }) async {
    final res = await api.updateWorkingServers(ftpServerIds: ftpServerIds);
    return res.servers;
  }

  Future<void> clearWorkingServers() async {
    await api.clearWorkingServers();
  }
}
