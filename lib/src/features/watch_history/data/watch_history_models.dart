enum WatchStatus {
  watching,
  completed,
  onHold,
  dropped;

  String get value {
    switch (this) {
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
      case 'watching':
        return WatchStatus.watching;
      case 'completed':
        return WatchStatus.completed;
      case 'on_hold':
        return WatchStatus.onHold;
      case 'dropped':
        return WatchStatus.dropped;
      default:
        return WatchStatus.watching;
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
      progress: ProgressInfo.fromJson(json['progress'] as Map<String, dynamic>),
      lastWatchedAt: DateTime.parse(json['lastWatchedAt'] as String),
    );
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
      episodes: episodesData
          .map((e) => EpisodeProgress.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
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
      final serverData = json['ftpServerId'] as Map<String, dynamic>;
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
          ? ProgressInfo.fromJson(json['progress'] as Map<String, dynamic>)
          : null,
      seriesProgress: seriesProgressData
          ?.map((s) => SeasonProgress.fromJson(s as Map<String, dynamic>))
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
      lastWatchedAt: DateTime.parse(json['lastWatchedAt'] as String),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}

class WatchHistoryResponse {
  WatchHistoryResponse({required this.message, this.watchHistory});

  final String message;
  final WatchHistory? watchHistory;

  factory WatchHistoryResponse.fromJson(Map<String, dynamic> json) {
    final watchHistoryData = json['watchHistory'];
    return WatchHistoryResponse(
      message: (json['message'] ?? '').toString(),
      watchHistory: watchHistoryData != null
          ? WatchHistory.fromJson(watchHistoryData as Map<String, dynamic>)
          : null,
    );
  }
}

class Pagination {
  Pagination({
    required this.total,
    required this.page,
    required this.limit,
    required this.pages,
  });

  final int total;
  final int page;
  final int limit;
  final int pages;

  factory Pagination.fromJson(Map<String, dynamic> json) {
    return Pagination(
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 50,
      pages: json['pages'] as int? ?? 0,
    );
  }
}

class WatchHistoryListResponse {
  WatchHistoryListResponse({
    required this.message,
    required this.watchHistories,
    required this.pagination,
  });

  final String message;
  final List<WatchHistory> watchHistories;
  final Pagination pagination;

  factory WatchHistoryListResponse.fromJson(Map<String, dynamic> json) {
    final watchHistoriesData = json['watchHistories'] as List? ?? [];
    return WatchHistoryListResponse(
      message: (json['message'] ?? '').toString(),
      watchHistories: watchHistoriesData
          .map((e) => WatchHistory.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: Pagination.fromJson(
        json['pagination'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}
