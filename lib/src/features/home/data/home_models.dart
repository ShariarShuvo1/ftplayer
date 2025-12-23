class ContentItem {
  ContentItem({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.serverName,
    required this.serverType,
    this.year,
    this.quality,
    this.rating,
    this.contentType,
    this.description,
    this.initialSeasonNumber,
    this.initialEpisodeNumber,
    this.initialEpisodeId,
    this.initialProgress,
  });

  final String id;
  final String title;
  final String posterUrl;
  final String serverName;
  final String serverType;
  final String? year;
  final String? quality;
  final double? rating;
  final String? contentType;
  final String? description;
  final int? initialSeasonNumber;
  final int? initialEpisodeNumber;
  final String? initialEpisodeId;
  final Duration? initialProgress;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'posterUrl': posterUrl,
    'serverName': serverName,
    'serverType': serverType,
    'year': year,
    'quality': quality,
    'rating': rating,
    'contentType': contentType,
    'description': description,
    'initialSeasonNumber': initialSeasonNumber,
    'initialEpisodeNumber': initialEpisodeNumber,
    'initialEpisodeId': initialEpisodeId,
    'initialProgress': initialProgress?.inSeconds,
  };

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      id: json['id'] as String,
      title: json['title'] as String,
      posterUrl: json['posterUrl'] as String,
      serverName: json['serverName'] as String,
      serverType: json['serverType'] as String,
      year: json['year'] as String?,
      quality: json['quality'] as String?,
      rating: json['rating'] as double?,
      contentType: json['contentType'] as String?,
      description: json['description'] as String?,
      initialSeasonNumber: json['initialSeasonNumber'] as int?,
      initialEpisodeNumber: json['initialEpisodeNumber'] as int?,
      initialEpisodeId: json['initialEpisodeId'] as String?,
      initialProgress: json['initialProgress'] != null
          ? Duration(seconds: json['initialProgress'] as int)
          : null,
    );
  }

  factory ContentItem.fromCircleFtp(
    Map<String, dynamic> json,
    String baseImageUrl,
    String serverName,
  ) {
    final image = json['image']?.toString();
    final posterUrl = image != null && image.isNotEmpty
        ? '$baseImageUrl$image'
        : '';

    return ContentItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      posterUrl: posterUrl,
      serverName: serverName,
      serverType: 'circleftp',
      year: json['year']?.toString(),
      quality: json['quality']?.toString(),
      contentType: json['type']?.toString(),
      description: json['metaData']?.toString(),
    );
  }

  factory ContentItem.fromDflix(
    Map<String, dynamic> json,
    String baseImageUrl,
    String serverName,
  ) {
    final poster = json['poster'] ?? json['TVposter'];
    final posterUrl = poster != null && poster.toString().isNotEmpty
        ? '$baseImageUrl/poster/$poster'
        : '';

    final rating = json['rating'];
    double? parsedRating;
    if (rating != null) {
      if (rating is num) {
        parsedRating = rating.toDouble();
      } else {
        parsedRating = double.tryParse(rating.toString());
      }
    }

    final title =
        json['MovieTitle'] ??
        json['TVtitle'] ??
        json['name'] ??
        json['title'] ??
        '';
    final year = json['MovieYear'] ?? json['releaseYear'] ?? '';
    final quality = json['MovieQuality'] ?? json['quality'] ?? '';

    return ContentItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: title.toString(),
      posterUrl: posterUrl,
      serverName: serverName,
      serverType: 'dflix',
      year: year.toString().isNotEmpty ? year.toString() : null,
      quality: quality.toString().isNotEmpty ? quality.toString() : null,
      rating: parsedRating,
      contentType: json['FileType']?.toString(),
      description: json['Story']?.toString() ?? json['description']?.toString(),
    );
  }
}

class HomeContentData {
  HomeContentData({
    required this.featured,
    required this.trending,
    required this.latest,
    required this.tvSeries,
  });

  final List<ContentItem> featured;
  final List<ContentItem> trending;
  final List<ContentItem> latest;
  final List<ContentItem> tvSeries;

  factory HomeContentData.empty() {
    return HomeContentData(
      featured: [],
      trending: [],
      latest: [],
      tvSeries: [],
    );
  }
}
