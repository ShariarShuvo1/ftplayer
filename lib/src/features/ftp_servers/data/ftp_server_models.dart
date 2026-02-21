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
}
