import 'package:flutter_riverpod/flutter_riverpod.dart';

final currentPlayingContentProvider = StateProvider<CurrentPlayingContent?>(
  (ref) => null,
);

class CurrentPlayingContent {
  const CurrentPlayingContent({
    required this.contentId,
    this.seasonNumber,
    this.episodeNumber,
  });

  final String contentId;
  final int? seasonNumber;
  final int? episodeNumber;

  CurrentPlayingContent copyWith({
    String? contentId,
    int? seasonNumber,
    int? episodeNumber,
  }) {
    return CurrentPlayingContent(
      contentId: contentId ?? this.contentId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
    );
  }
}
