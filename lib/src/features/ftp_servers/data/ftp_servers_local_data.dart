import 'ftp_server_models.dart';

class FtpServersLocalData {
  static final List<FtpServerDto> allServers = [
    FtpServerDto(
      id: 'circleftp_server',
      name: 'CircleFTP Server',
      description:
          'Primary CircleFTP server with movies, series, games, and multi-file content',
      serverType: 'circleftp',
      ispProvider: 'Circle Internet',
      pingUrl: 'http://new.circleftp.net/',
      isActive: true,
      priority: 10,
    ),
    FtpServerDto(
      id: 'dflix_server',
      name: 'Dflix Server',
      description:
          'Dflix streaming server with Hollywood, Bollywood, and international content',
      serverType: 'dflix',
      ispProvider: 'Dot Internet',
      pingUrl: 'http://www.dflix.live',
      isActive: true,
      priority: 5,
    ),
    FtpServerDto(
      id: 'amaderftp_server',
      name: 'AmaderFTP Server',
      description: 'AmaderFTP Jellyfin-based server with Movies and TV Series',
      serverType: 'amaderftp',
      ispProvider: 'Amader.Net',
      pingUrl: 'http://amaderftp.net:8096/',
      isActive: true,
      priority: 8,
    ),
  ];

  static List<FtpServerDto> getAllServers() {
    return List.from(allServers);
  }

  static List<FtpServerDto> getPublicServers() {
    return allServers.where((server) => server.isActive).toList();
  }

  static FtpServerDto? getServerById(String id) {
    try {
      return allServers.firstWhere((server) => server.id == id);
    } catch (_) {
      return null;
    }
  }

  static FtpServerDto? getServerByName(String name) {
    try {
      return allServers.firstWhere((server) => server.name == name);
    } catch (_) {
      return null;
    }
  }
}
