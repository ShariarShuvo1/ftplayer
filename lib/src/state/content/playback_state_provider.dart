import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PlaybackStateCache {
  final String contentId;
  final Player? player;
  final VideoController? videoController;
  final String? currentVideoUrl;
  final int? currentSeasonNumber;
  final int? currentEpisodeNumber;
  final String? currentEpisodeId;
  final String? currentEpisodeTitle;
  final Duration? currentPosition;
  final DateTime cachedAt;

  PlaybackStateCache({
    required this.contentId,
    this.player,
    this.videoController,
    this.currentVideoUrl,
    this.currentSeasonNumber,
    this.currentEpisodeNumber,
    this.currentEpisodeId,
    this.currentEpisodeTitle,
    this.currentPosition,
    required this.cachedAt,
  });

  bool isExpired(Duration expirationDuration) {
    final now = DateTime.now();
    return now.difference(cachedAt) > expirationDuration;
  }
}

class PlaybackStateNotifier extends StateNotifier<PlaybackStateCache?> {
  PlaybackStateNotifier() : super(null);

  void cachePlaybackState({
    required String contentId,
    Player? player,
    VideoController? videoController,
    String? currentVideoUrl,
    int? currentSeasonNumber,
    int? currentEpisodeNumber,
    String? currentEpisodeId,
    String? currentEpisodeTitle,
    Duration? currentPosition,
  }) {
    state = PlaybackStateCache(
      contentId: contentId,
      player: player,
      videoController: videoController,
      currentVideoUrl: currentVideoUrl,
      currentSeasonNumber: currentSeasonNumber,
      currentEpisodeNumber: currentEpisodeNumber,
      currentEpisodeId: currentEpisodeId,
      currentEpisodeTitle: currentEpisodeTitle,
      currentPosition: currentPosition,
      cachedAt: DateTime.now(),
    );
  }

  void clearPlaybackState() {
    state = null;
  }

  PlaybackStateCache? getPlaybackStateIfValid(String contentId) {
    if (state != null &&
        state!.contentId == contentId &&
        !state!.isExpired(const Duration(minutes: 5))) {
      return state;
    }
    return null;
  }
}

final playbackStateProvider =
    StateNotifierProvider<PlaybackStateNotifier, PlaybackStateCache?>((ref) {
      return PlaybackStateNotifier();
    });
