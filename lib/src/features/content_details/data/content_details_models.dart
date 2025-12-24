class ContentDetails {
  ContentDetails({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.serverName,
    required this.serverType,
    required this.contentType,
    this.year,
    this.quality,
    this.rating,
    this.description,
    this.watchTime,
    this.tags,
    this.videoUrl,
    this.seasons,
  });

  final String id;
  final String title;
  final String posterUrl;
  final String serverName;
  final String serverType;
  final String contentType;
  final String? year;
  final String? quality;
  final double? rating;
  final String? description;
  final String? watchTime;
  final String? tags;
  final String? videoUrl;
  final List<Season>? seasons;

  bool get isSeries => contentType == 'series' || seasons != null;
  bool get hasVideoUrl => videoUrl != null && videoUrl!.isNotEmpty;

  Map<String, dynamic> toMetadata() => {
    'id': id,
    'title': title,
    'posterUrl': posterUrl,
    'serverName': serverName,
    'serverType': serverType,
    'contentType': contentType,
    'year': year,
    'quality': quality,
    'rating': rating,
    'description': description,
    'watchTime': watchTime,
    'tags': tags,
    'videoUrl': videoUrl,
    'seasons': seasons
        ?.map(
          (s) => {
            'seasonName': s.seasonName,
            'episodes': s.episodes
                .map(
                  (e) => {
                    'title': e.title,
                    'link': e.link,
                    'id': e.id,
                    'episodeNumber': e.episodeNumber,
                  },
                )
                .toList(),
          },
        )
        .toList(),
  };

  factory ContentDetails.fromMetadata(Map<String, dynamic> metadata) {
    final typedMetadata = _castMetadata(metadata);

    List<Season>? seasons;
    final seasonsData = typedMetadata['seasons'] as List?;
    if (seasonsData != null) {
      seasons = seasonsData.map((s) {
        final seasonMap = s is Map
            ? _castToStringDynamic(s)
            : s as Map<String, dynamic>;
        return Season.fromJson(seasonMap);
      }).toList();
    }

    final localPosterPath = typedMetadata['localPosterPath']?.toString();
    final posterUrl =
        localPosterPath ?? typedMetadata['posterUrl']?.toString() ?? '';

    return ContentDetails(
      id: typedMetadata['id']?.toString() ?? '',
      title: typedMetadata['title']?.toString() ?? '',
      posterUrl: posterUrl,
      serverName: typedMetadata['serverName']?.toString() ?? '',
      serverType: typedMetadata['serverType']?.toString() ?? '',
      contentType: typedMetadata['contentType']?.toString() ?? '',
      year: typedMetadata['year']?.toString(),
      quality: typedMetadata['quality']?.toString(),
      rating: typedMetadata['rating'] is num
          ? (typedMetadata['rating'] as num).toDouble()
          : null,
      description: typedMetadata['description']?.toString(),
      watchTime: typedMetadata['watchTime']?.toString(),
      tags: typedMetadata['tags']?.toString(),
      videoUrl: typedMetadata['videoUrl']?.toString(),
      seasons: seasons,
    );
  }

  static Map<String, dynamic> _castMetadata(dynamic input) {
    if (input is Map<String, dynamic>) {
      return input;
    }
    if (input is Map) {
      return _castToStringDynamic(input);
    }
    return {};
  }

  static Map<String, dynamic> _castToStringDynamic(Map input) {
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      final stringKey = key.toString();
      if (value is Map) {
        result[stringKey] = _castToStringDynamic(value);
      } else if (value is List) {
        result[stringKey] = value
            .map((item) => item is Map ? _castToStringDynamic(item) : item)
            .toList();
      } else {
        result[stringKey] = value;
      }
    });
    return result;
  }

  factory ContentDetails.fromCircleFtp(
    Map<String, dynamic> json,
    String baseImageUrl,
    String serverName,
  ) {
    final image = json['image']?.toString();
    final posterUrl = image != null && image.isNotEmpty
        ? '$baseImageUrl$image'
        : '';

    final contentType = json['type']?.toString() ?? 'singleVideo';
    final content = json['content'];

    String? videoUrl;
    List<Season>? seasons;

    if (contentType == 'singleVideo' || contentType == 'singleFile') {
      videoUrl = content?.toString();
    } else if (contentType == 'series' && content is List) {
      seasons = content
          .map((s) => Season.fromJson(s as Map<String, dynamic>))
          .toList();
    } else if (contentType == 'multiFile' && content is List) {
      seasons = [
        Season(
          seasonName: 'Files',
          episodes: content
              .map((e) => Episode.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      ];
    }

    return ContentDetails(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? '').toString(),
      posterUrl: posterUrl,
      serverName: serverName,
      serverType: 'circleftp',
      contentType: contentType,
      year: json['year']?.toString(),
      quality: json['quality']?.toString(),
      description: json['metaData']?.toString(),
      watchTime: json['watchTime']?.toString(),
      tags: json['tags']?.toString(),
      videoUrl: videoUrl,
      seasons: seasons,
    );
  }

  factory ContentDetails.fromDflix(
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

    final videoUrl = json['MovieWatchLink']?.toString();
    final fileLocation = json['FileLocation']?.toString();

    final contentType = fileLocation != null ? 'series' : 'singleVideo';

    return ContentDetails(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: title.toString(),
      posterUrl: posterUrl,
      serverName: serverName,
      serverType: 'dflix',
      contentType: contentType,
      year: year.toString().isNotEmpty ? year.toString() : null,
      quality: quality.toString().isNotEmpty ? quality.toString() : null,
      rating: parsedRating,
      description: json['Story']?.toString() ?? json['description']?.toString(),
      videoUrl: videoUrl,
    );
  }
}

class Season {
  Season({required this.seasonName, required this.episodes});

  final String seasonName;
  final List<Episode> episodes;

  factory Season.fromJson(Map<String, dynamic> json) {
    final episodes =
        (json['episodes'] as List?)
            ?.map((e) => Episode.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return Season(
      seasonName: json['seasonName']?.toString() ?? 'Season',
      episodes: episodes,
    );
  }
}

class Episode {
  Episode({
    required this.title,
    required this.link,
    this.id,
    this.episodeNumber,
  });

  final String title;
  final String link;
  final String? id;
  final int? episodeNumber;

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      title: json['title']?.toString() ?? 'Episode',
      link: json['link']?.toString() ?? '',
      id: json['id']?.toString() ?? json['link']?.toString(),
      episodeNumber: json['episodeNumber'] as int?,
    );
  }
}
