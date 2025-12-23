class SearchResult {
  SearchResult({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.serverName,
    required this.serverType,
    required this.contentType,
    this.year,
    this.quality,
    this.description,
  });

  final String id;
  final String title;
  final String posterUrl;
  final String serverName;
  final String serverType;
  final String contentType;
  final String? year;
  final String? quality;
  final String? description;

  factory SearchResult.fromCircleFtp(
    Map<String, dynamic> json,
    String baseImageUrl,
    String serverName,
  ) {
    final image = json['image']?.toString();
    final posterUrl = image != null && image.isNotEmpty
        ? '$baseImageUrl$image'
        : '';

    final type = json['type']?.toString() ?? '';
    final normalizedType = _normalizeContentType(type);

    return SearchResult(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['name'] ?? json['title'] ?? '').toString(),
      posterUrl: posterUrl,
      serverName: serverName,
      serverType: 'circleftp',
      contentType: normalizedType,
      year: json['year']?.toString(),
      quality: json['quality']?.toString(),
      description: json['metaData']?.toString(),
    );
  }

  factory SearchResult.fromDflix(
    Map<String, dynamic> json,
    String baseImageUrl,
    String serverName,
  ) {
    final poster = json['poster'] ?? json['TVposter'];
    final posterUrl = poster != null && poster.toString().isNotEmpty
        ? '$baseImageUrl/poster/$poster'
        : '';

    final title =
        json['MovieTitle'] ??
        json['TVtitle'] ??
        json['name'] ??
        json['title'] ??
        '';
    final year = json['MovieYear'] ?? json['releaseYear'] ?? '';
    final quality = json['MovieQuality'] ?? json['quality'] ?? '';

    final hasTvTitle = json['TVtitle'] != null;
    final hasFileLocation = json['FileLocation'] != null;
    final normalizedType = (hasTvTitle || hasFileLocation) ? 'series' : 'movie';

    return SearchResult(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: title.toString(),
      posterUrl: posterUrl,
      serverName: serverName,
      serverType: 'dflix',
      contentType: normalizedType,
      year: year.toString().isNotEmpty ? year.toString() : null,
      quality: quality.toString().isNotEmpty ? quality.toString() : null,
      description: json['Story']?.toString() ?? json['description']?.toString(),
    );
  }

  static String _normalizeContentType(String type) {
    final lowerType = type.toLowerCase();
    if (lowerType == 'series' || lowerType == 'show' || lowerType == 'tv') {
      return 'series';
    }
    if (lowerType == 'singlevideo' || lowerType == 'movie') {
      return 'movie';
    }
    return lowerType;
  }

  bool get isMovieOrSeries =>
      contentType == 'movie' ||
      contentType == 'series' ||
      contentType == 'singlevideo';
}

class SearchResultsData {
  SearchResultsData({required this.results, required this.query});

  final List<SearchResult> results;
  final String query;

  factory SearchResultsData.empty(String query) {
    return SearchResultsData(results: [], query: query);
  }
}
