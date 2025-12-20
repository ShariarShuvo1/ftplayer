import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'ftp_server_models.dart';

class FtpServerApi {
  FtpServerApi(this.dio);

  final Dio dio;
  final _logger = Logger();

  Future<FtpServersResponse> getAllServers() async {
    try {
      final res = await dio.get('/ftp-servers');
      _logger.d('Fetched FTP servers: ${res.data}');
      return FtpServersResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error fetching servers', error: e);
      rethrow;
    }
  }

  Future<FtpServersResponse> getAllPublicServers() async {
    try {
      final res = await dio.get('/ftp-servers/all-public');
      _logger.d('Fetched all public FTP servers: ${res.data}');
      return FtpServersResponse.fromJson(res.data as Map<String, dynamic>);
    } catch (e) {
      _logger.e('Error fetching public servers', error: e);
      rethrow;
    }
  }

  Future<WorkingFtpServersResponse> getWorkingServers() async {
    final res = await dio.get('/working-ftp-servers');
    return WorkingFtpServersResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<WorkingFtpServersResponse> updateWorkingServers({
    required List<String> ftpServerIds,
  }) async {
    final res = await dio.put(
      '/working-ftp-servers',
      data: {'ftpServerIds': ftpServerIds},
    );
    return WorkingFtpServersResponse.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> clearWorkingServers() async {
    await dio.delete('/working-ftp-servers');
  }
}
