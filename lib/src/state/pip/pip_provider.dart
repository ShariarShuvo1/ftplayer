import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'pip_state.dart';

class PipNotifier extends StateNotifier<PipState> {
  PipNotifier() : super(PipState.empty);

  void activatePip({
    required Player player,
    required VideoController videoController,
    required String videoUrl,
    required String videoTitle,
    Map<String, dynamic>? contentItemJson,
    Offset? initialPosition,
    String? currentVideoUrl,
    int? currentSeasonNumber,
    int? currentEpisodeNumber,
    String? currentEpisodeId,
    String? currentEpisodeTitle,
  }) {
    state = PipState(
      isActive: true,
      player: player,
      videoController: videoController,
      videoUrl: videoUrl,
      videoTitle: videoTitle,
      contentItemJson: contentItemJson,
      position: initialPosition ?? const Offset(16, 100),
      currentVideoUrl: currentVideoUrl,
      currentSeasonNumber: currentSeasonNumber,
      currentEpisodeNumber: currentEpisodeNumber,
      currentEpisodeId: currentEpisodeId,
      currentEpisodeTitle: currentEpisodeTitle,
    );
  }

  void deactivatePip({bool disposePlayer = true}) {
    final oldPlayer = state.player;
    state = PipState.empty;
    if (disposePlayer && oldPlayer != null) {
      try {
        oldPlayer.dispose();
      } catch (e) {
        // Ignore disposal errors
      }
    }
  }

  void updatePosition(Offset position) {
    state = state.copyWith(position: position);
  }
}

final pipProvider = StateNotifierProvider<PipNotifier, PipState>((ref) {
  return PipNotifier();
});
