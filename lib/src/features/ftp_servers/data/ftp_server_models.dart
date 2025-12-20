class FtpServerDto {
  FtpServerDto({
    required this.id,
    required this.name,
    required this.description,
    required this.serverType,
    required this.ispProvider,
    required this.pingUrl,
    required this.isActive,
    required this.priority,
  });

  final String id;
  final String name;
  final String? description;
  final String serverType;
  final String ispProvider;
  final String? pingUrl;
  final bool isActive;
  final int priority;

  factory FtpServerDto.fromJson(Map<String, dynamic> json) {
    return FtpServerDto(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: json['description']?.toString(),
      serverType: (json['serverType'] ?? '').toString(),
      ispProvider: (json['ispProvider'] ?? '').toString(),
      pingUrl: json['pingUrl']?.toString(),
      isActive: json['isActive'] == true,
      priority: int.tryParse((json['priority'] ?? 0).toString()) ?? 0,
    );
  }
}

class FtpServersResponse {
  FtpServersResponse({required this.message, required this.servers});

  final String message;
  final List<FtpServerDto> servers;

  factory FtpServersResponse.fromJson(Map<String, dynamic> json) {
    final serversData = json['ftpServers'] ?? json['servers'] ?? [];
    return FtpServersResponse(
      message: (json['message'] ?? '').toString(),
      servers: (serversData as List)
          .map((s) => FtpServerDto.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class WorkingFtpServersResponse {
  WorkingFtpServersResponse({required this.message, required this.servers});

  final String message;
  final List<FtpServerDto> servers;

  factory WorkingFtpServersResponse.fromJson(Map<String, dynamic> json) {
    final serversData = json['workingFtpServers'] ?? [];
    return WorkingFtpServersResponse(
      message: (json['message'] ?? '').toString(),
      servers: (serversData as List)
          .map((s) => FtpServerDto.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class UpdateWorkingServersRequest {
  UpdateWorkingServersRequest({required this.ftpServerIds});

  final List<String> ftpServerIds;

  Map<String, dynamic> toJson() {
    return {'ftpServerIds': ftpServerIds};
  }
}
