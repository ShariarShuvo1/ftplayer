import 'package:hive/hive.dart';

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled;

  String get label {
    switch (this) {
      case DownloadStatus.queued:
        return 'Queued';
      case DownloadStatus.downloading:
        return 'Downloading';
      case DownloadStatus.paused:
        return 'Paused';
      case DownloadStatus.completed:
        return 'Completed';
      case DownloadStatus.failed:
        return 'Failed';
      case DownloadStatus.cancelled:
        return 'Cancelled';
    }
  }
}

@HiveType(typeId: 10)
class DownloadedContent {
  DownloadedContent({
    required this.id,
    required this.contentId,
    required this.title,
    required this.posterUrl,
    required this.description,
    required this.serverName,
    required this.serverType,
    required this.ftpServerId,
    required this.contentType,
    required this.videoUrl,
    required this.localPath,
    required this.fileSize,
    required this.downloadedAt,
    this.year,
    this.quality,
    this.rating,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeTitle,
    this.seriesTitle,
    this.totalSeasons,
    this.metadata,
    this.localPosterPath,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String contentId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String posterUrl;

  @HiveField(4)
  final String description;

  @HiveField(5)
  final String serverName;

  @HiveField(6)
  final String serverType;

  @HiveField(7)
  final String ftpServerId;

  @HiveField(8)
  final String contentType;

  @HiveField(9)
  final String videoUrl;

  @HiveField(10)
  final String localPath;

  @HiveField(11)
  final int fileSize;

  @HiveField(12)
  final DateTime downloadedAt;

  @HiveField(13)
  final String? year;

  @HiveField(14)
  final String? quality;

  @HiveField(15)
  final double? rating;

  @HiveField(16)
  final int? seasonNumber;

  @HiveField(17)
  final int? episodeNumber;

  @HiveField(18)
  final String? episodeTitle;

  @HiveField(19)
  final String? seriesTitle;

  @HiveField(20)
  final int? totalSeasons;

  @HiveField(21)
  final Map<String, dynamic>? metadata;

  @HiveField(22)
  final String? localPosterPath;

  bool get isEpisode => seasonNumber != null && episodeNumber != null;
  bool get isSeries => contentType == 'series' || isEpisode;

  String get displayTitle {
    if (isEpisode) {
      return 'S${seasonNumber}E$episodeNumber${episodeTitle != null ? ' - $episodeTitle' : ''}';
    }
    return title;
  }

  String get episodeLabel {
    if (!isEpisode) return '';
    return 'S${seasonNumber}E$episodeNumber';
  }

  DownloadedContent copyWith({
    String? id,
    String? contentId,
    String? title,
    String? posterUrl,
    String? description,
    String? serverName,
    String? serverType,
    String? ftpServerId,
    String? contentType,
    String? videoUrl,
    String? localPath,
    int? fileSize,
    DateTime? downloadedAt,
    String? year,
    String? quality,
    double? rating,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
    String? seriesTitle,
    int? totalSeasons,
    Map<String, dynamic>? metadata,
    String? localPosterPath,
  }) {
    return DownloadedContent(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      description: description ?? this.description,
      serverName: serverName ?? this.serverName,
      serverType: serverType ?? this.serverType,
      ftpServerId: ftpServerId ?? this.ftpServerId,
      contentType: contentType ?? this.contentType,
      videoUrl: videoUrl ?? this.videoUrl,
      localPath: localPath ?? this.localPath,
      fileSize: fileSize ?? this.fileSize,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      year: year ?? this.year,
      quality: quality ?? this.quality,
      rating: rating ?? this.rating,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      metadata: metadata ?? this.metadata,
      localPosterPath: localPosterPath ?? this.localPosterPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentId': contentId,
      'title': title,
      'posterUrl': posterUrl,
      'description': description,
      'serverName': serverName,
      'serverType': serverType,
      'ftpServerId': ftpServerId,
      'contentType': contentType,
      'videoUrl': videoUrl,
      'localPath': localPath,
      'fileSize': fileSize,
      'downloadedAt': downloadedAt.toIso8601String(),
      'year': year,
      'quality': quality,
      'rating': rating,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
      'seriesTitle': seriesTitle,
      'totalSeasons': totalSeasons,
      'metadata': metadata,
      'localPosterPath': localPosterPath,
    };
  }

  factory DownloadedContent.fromJson(Map<String, dynamic> json) {
    return DownloadedContent(
      id: json['id'] as String,
      contentId: json['contentId'] as String,
      title: json['title'] as String,
      posterUrl: json['posterUrl'] as String,
      description: json['description'] as String,
      serverName: json['serverName'] as String,
      serverType: json['serverType'] as String,
      ftpServerId: json['ftpServerId'] as String,
      contentType: json['contentType'] as String,
      videoUrl: json['videoUrl'] as String,
      localPath: json['localPath'] as String,
      fileSize: json['fileSize'] as int,
      downloadedAt: DateTime.parse(json['downloadedAt'] as String),
      year: json['year'] as String?,
      quality: json['quality'] as String?,
      rating: json['rating'] as double?,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
      episodeTitle: json['episodeTitle'] as String?,
      seriesTitle: json['seriesTitle'] as String?,
      totalSeasons: json['totalSeasons'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      localPosterPath: json['localPosterPath'] as String?,
    );
  }
}

@HiveType(typeId: 11)
class DownloadTask {
  DownloadTask({
    required this.id,
    required this.contentId,
    required this.title,
    required this.posterUrl,
    required this.description,
    required this.serverName,
    required this.serverType,
    required this.ftpServerId,
    required this.contentType,
    required this.videoUrl,
    required this.status,
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.createdAt,
    this.year,
    this.quality,
    this.rating,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeTitle,
    this.seriesTitle,
    this.totalSeasons,
    this.metadata,
    this.taskId,
    this.localPath,
    this.speed,
    this.eta,
    this.error,
  });

  @HiveField(0)
  final String id;

  @HiveField(1)
  final String contentId;

  @HiveField(2)
  final String title;

  @HiveField(3)
  final String posterUrl;

  @HiveField(4)
  final String description;

  @HiveField(5)
  final String serverName;

  @HiveField(6)
  final String serverType;

  @HiveField(7)
  final String ftpServerId;

  @HiveField(8)
  final String contentType;

  @HiveField(9)
  final String videoUrl;

  @HiveField(10)
  final DownloadStatus status;

  @HiveField(11)
  final double progress;

  @HiveField(12)
  final int downloadedBytes;

  @HiveField(13)
  final int totalBytes;

  @HiveField(14)
  final DateTime createdAt;

  @HiveField(15)
  final String? year;

  @HiveField(16)
  final String? quality;

  @HiveField(17)
  final double? rating;

  @HiveField(18)
  final int? seasonNumber;

  @HiveField(19)
  final int? episodeNumber;

  @HiveField(20)
  final String? episodeTitle;

  @HiveField(21)
  final String? seriesTitle;

  @HiveField(22)
  final int? totalSeasons;

  @HiveField(23)
  final Map<String, dynamic>? metadata;

  @HiveField(24)
  final String? taskId;

  @HiveField(25)
  final String? localPath;

  @HiveField(26)
  final double? speed;

  @HiveField(27)
  final int? eta;

  @HiveField(28)
  final String? error;

  bool get isEpisode => seasonNumber != null && episodeNumber != null;
  bool get isSeries => contentType == 'series' || isEpisode;

  String get displayTitle {
    if (isEpisode) {
      return 'S${seasonNumber}E$episodeNumber${episodeTitle != null ? ' - $episodeTitle' : ''}';
    }
    return title;
  }

  String get episodeLabel {
    if (!isEpisode) return '';
    return 'S${seasonNumber}E$episodeNumber';
  }

  String get downloadedSizeFormatted {
    return _formatFileSize(downloadedBytes);
  }

  String get totalSizeFormatted {
    return _formatFileSize(totalBytes);
  }

  String get speedFormatted {
    if (speed == null || speed! <= 0) return '--';
    return '${_formatFileSize(speed!.toInt())}/s';
  }

  String get etaFormatted {
    if (eta == null || eta! <= 0) return '--';
    final duration = Duration(seconds: eta!);
    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }
    return '${duration.inSeconds}s';
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  DownloadTask copyWith({
    String? id,
    String? contentId,
    String? title,
    String? posterUrl,
    String? description,
    String? serverName,
    String? serverType,
    String? ftpServerId,
    String? contentType,
    String? videoUrl,
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    DateTime? createdAt,
    String? year,
    String? quality,
    double? rating,
    int? seasonNumber,
    int? episodeNumber,
    String? episodeTitle,
    String? seriesTitle,
    int? totalSeasons,
    Map<String, dynamic>? metadata,
    String? taskId,
    String? localPath,
    double? speed,
    int? eta,
    String? error,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      contentId: contentId ?? this.contentId,
      title: title ?? this.title,
      posterUrl: posterUrl ?? this.posterUrl,
      description: description ?? this.description,
      serverName: serverName ?? this.serverName,
      serverType: serverType ?? this.serverType,
      ftpServerId: ftpServerId ?? this.ftpServerId,
      contentType: contentType ?? this.contentType,
      videoUrl: videoUrl ?? this.videoUrl,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      createdAt: createdAt ?? this.createdAt,
      year: year ?? this.year,
      quality: quality ?? this.quality,
      rating: rating ?? this.rating,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      seriesTitle: seriesTitle ?? this.seriesTitle,
      totalSeasons: totalSeasons ?? this.totalSeasons,
      metadata: metadata ?? this.metadata,
      taskId: taskId ?? this.taskId,
      localPath: localPath ?? this.localPath,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      error: error ?? this.error,
    );
  }

  DownloadedContent toDownloadedContent(
    String filePath,
    int fileSize, {
    String? localPosterPath,
  }) {
    return DownloadedContent(
      id: id,
      contentId: contentId,
      title: title,
      posterUrl: posterUrl,
      description: description,
      serverName: serverName,
      serverType: serverType,
      ftpServerId: ftpServerId,
      contentType: contentType,
      videoUrl: videoUrl,
      localPath: filePath,
      fileSize: fileSize,
      downloadedAt: DateTime.now(),
      year: year,
      quality: quality,
      rating: rating,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      seriesTitle: seriesTitle,
      totalSeasons: totalSeasons,
      metadata: metadata,
      localPosterPath: localPosterPath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contentId': contentId,
      'title': title,
      'posterUrl': posterUrl,
      'description': description,
      'serverName': serverName,
      'serverType': serverType,
      'ftpServerId': ftpServerId,
      'contentType': contentType,
      'videoUrl': videoUrl,
      'status': status.index,
      'progress': progress,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'createdAt': createdAt.toIso8601String(),
      'year': year,
      'quality': quality,
      'rating': rating,
      'seasonNumber': seasonNumber,
      'episodeNumber': episodeNumber,
      'episodeTitle': episodeTitle,
      'seriesTitle': seriesTitle,
      'totalSeasons': totalSeasons,
      'metadata': metadata,
      'taskId': taskId,
      'localPath': localPath,
      'speed': speed,
      'eta': eta,
      'error': error,
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      id: json['id'] as String,
      contentId: json['contentId'] as String,
      title: json['title'] as String,
      posterUrl: json['posterUrl'] as String,
      description: json['description'] as String,
      serverName: json['serverName'] as String,
      serverType: json['serverType'] as String,
      ftpServerId: json['ftpServerId'] as String,
      contentType: json['contentType'] as String,
      videoUrl: json['videoUrl'] as String,
      status: DownloadStatus.values[json['status'] as int],
      progress: (json['progress'] as num).toDouble(),
      downloadedBytes: json['downloadedBytes'] as int,
      totalBytes: json['totalBytes'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String),
      year: json['year'] as String?,
      quality: json['quality'] as String?,
      rating: json['rating'] as double?,
      seasonNumber: json['seasonNumber'] as int?,
      episodeNumber: json['episodeNumber'] as int?,
      episodeTitle: json['episodeTitle'] as String?,
      seriesTitle: json['seriesTitle'] as String?,
      totalSeasons: json['totalSeasons'] as int?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      taskId: json['taskId'] as String?,
      localPath: json['localPath'] as String?,
      speed: json['speed'] as double?,
      eta: json['eta'] as int?,
      error: json['error'] as String?,
    );
  }
}
