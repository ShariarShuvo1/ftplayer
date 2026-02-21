enum WatchStatus {
  planned,
  watching,
  completed,
  onHold,
  dropped;

  String get value {
    switch (this) {
      case WatchStatus.planned:
        return 'planned';
      case WatchStatus.watching:
        return 'watching';
      case WatchStatus.completed:
        return 'completed';
      case WatchStatus.onHold:
        return 'on_hold';
      case WatchStatus.dropped:
        return 'dropped';
    }
  }

  String get label {
    switch (this) {
      case WatchStatus.planned:
        return 'Planned';
      case WatchStatus.watching:
        return 'Watching';
      case WatchStatus.completed:
        return 'Completed';
      case WatchStatus.onHold:
        return 'On Hold';
      case WatchStatus.dropped:
        return 'Dropped';
    }
  }

  static WatchStatus fromString(String value) {
    switch (value) {
      case 'planned':
        return WatchStatus.planned;
      case 'watching':
        return WatchStatus.watching;
      case 'completed':
        return WatchStatus.completed;
      case 'on_hold':
        return WatchStatus.onHold;
      case 'dropped':
        return WatchStatus.dropped;
      default:
        return WatchStatus.planned;
    }
  }
}

class ProgressInfo {
  ProgressInfo({
    required this.currentTime,
    required this.duration,
    required this.percentage,
  });

  final double currentTime;
  final double duration;
  final double percentage;

  factory ProgressInfo.fromJson(Map<String, dynamic> json) {
    return ProgressInfo(
      currentTime: (json['currentTime'] ?? 0).toDouble(),
      duration: (json['duration'] ?? 0).toDouble(),
      percentage: (json['percentage'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentTime': currentTime,
      'duration': duration,
      'percentage': percentage,
    };
  }
}

class EpisodeProgress {
  EpisodeProgress({
    required this.episodeNumber,
    this.episodeId,
    this.episodeTitle,
    required this.status,
    required this.progress,
    required this.lastWatchedAt,
  });

  final int episodeNumber;
  final String? episodeId;
  final String? episodeTitle;
  final WatchStatus status;
  final ProgressInfo progress;
  final DateTime lastWatchedAt;

  factory EpisodeProgress.fromJson(Map<String, dynamic> json) {
    return EpisodeProgress(
      episodeNumber: json['episodeNumber'] as int,
      episodeId: json['episodeId']?.toString(),
      episodeTitle: json['episodeTitle']?.toString(),
      status: WatchStatus.fromString(json['status']?.toString() ?? 'watching'),
      progress: ProgressInfo.fromJson(
        json['progress'] is Map<String, dynamic>
            ? json['progress']
            : Map<String, dynamic>.from(
                (json['progress'] as Map).map(
                  (k, v) => MapEntry(k.toString(), v),
                ),
              ),
      ),
      lastWatchedAt: DateTime.parse(json['lastWatchedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'episodeNumber': episodeNumber,
      'episodeId': episodeId,
      'episodeTitle': episodeTitle,
      'status': status.value,
      'progress': progress.toJson(),
      'lastWatchedAt': lastWatchedAt.toIso8601String(),
    };
  }
}

class SeasonProgress {
  SeasonProgress({
    required this.seasonNumber,
    this.seasonId,
    required this.episodes,
  });

  final int seasonNumber;
  final String? seasonId;
  final List<EpisodeProgress> episodes;

  factory SeasonProgress.fromJson(Map<String, dynamic> json) {
    final episodesData = json['episodes'] as List? ?? [];
    return SeasonProgress(
      seasonNumber: json['seasonNumber'] as int,
      seasonId: json['seasonId']?.toString(),
      episodes: episodesData.map((e) {
        final episodeMap = e is Map<String, dynamic>
            ? e
            : Map<String, dynamic>.from(
                (e as Map).map((k, v) => MapEntry(k.toString(), v)),
              );
        return EpisodeProgress.fromJson(episodeMap);
      }).toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seasonNumber': seasonNumber,
      'seasonId': seasonId,
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }
}

class WatchHistory {
  WatchHistory({
    required this.id,
    required this.userId,
    required this.ftpServerId,
    required this.serverName,
    required this.serverType,
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
    required this.status,
    this.progress,
    this.seriesProgress,
    this.metadata,
    required this.lastWatchedAt,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String ftpServerId;
  final String serverName;
  final String serverType;
  final String contentType;
  final String contentId;
  final String contentTitle;
  final WatchStatus status;
  final ProgressInfo? progress;
  final List<SeasonProgress>? seriesProgress;
  final Map<String, dynamic>? metadata;
  final DateTime lastWatchedAt;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory WatchHistory.fromJson(Map<String, dynamic> json) {
    final seriesProgressData = json['seriesProgress'] as List?;

    String serverName = '';
    String ftpServerIdValue = '';

    if (json['ftpServerId'] is Map) {
      final serverDataRaw = json['ftpServerId'] as Map;
      final serverData = Map<String, dynamic>.from(
        serverDataRaw.map((k, v) => MapEntry(k.toString(), v)),
      );
      ftpServerIdValue = (serverData['_id'] ?? '').toString();
      serverName = (serverData['name'] ?? '').toString();
    } else {
      ftpServerIdValue = (json['ftpServerId'] ?? '').toString();
      serverName = (json['serverName'] ?? '').toString();
    }

    return WatchHistory(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      ftpServerId: ftpServerIdValue,
      serverName: serverName,
      serverType: (json['serverType'] ?? '').toString(),
      contentType: (json['contentType'] ?? '').toString(),
      contentId: (json['contentId'] ?? '').toString(),
      contentTitle: (json['contentTitle'] ?? '').toString(),
      status: WatchStatus.fromString(json['status']?.toString() ?? 'watching'),
      progress: json['progress'] != null
          ? ProgressInfo.fromJson(
              json['progress'] is Map<String, dynamic>
                  ? json['progress']
                  : Map<String, dynamic>.from(
                      (json['progress'] as Map).map(
                        (k, v) => MapEntry(k.toString(), v),
                      ),
                    ),
            )
          : null,
      seriesProgress: seriesProgressData?.map((s) {
        final seasonMap = s is Map<String, dynamic>
            ? s
            : Map<String, dynamic>.from(
                (s as Map).map((k, v) => MapEntry(k.toString(), v)),
              );
        return SeasonProgress.fromJson(seasonMap);
      }).toList(),
      metadata: json['metadata'] != null
          ? (json['metadata'] is Map<String, dynamic>
                ? json['metadata']
                : Map<String, dynamic>.from(
                    (json['metadata'] as Map).map(
                      (k, v) => MapEntry(k.toString(), v),
                    ),
                  ))
          : null,
      lastWatchedAt: DateTime.parse(json['lastWatchedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'ftpServerId': ftpServerId,
      'serverName': serverName,
      'serverType': serverType,
      'contentType': contentType,
      'contentId': contentId,
      'contentTitle': contentTitle,
      'status': status.value,
      'progress': progress?.toJson(),
      'seriesProgress': seriesProgress?.map((s) => s.toJson()).toList(),
      'metadata': metadata,
      'lastWatchedAt': lastWatchedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
