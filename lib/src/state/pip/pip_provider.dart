import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'pip_state.dart';

final _logger = Logger();

class PipNotifier extends StateNotifier<PipState> {
  PipNotifier() : super(PipState.empty);

  void activatePip({
    required Player player,
    required VideoController videoController,
    required String videoUrl,
    required String videoTitle,
    Map<String, dynamic>? contentItemJson,
    Offset? initialPosition,
  }) {
    _logger.d('Activating PiP: $videoTitle');

    state = PipState(
      isActive: true,
      player: player,
      videoController: videoController,
      videoUrl: videoUrl,
      videoTitle: videoTitle,
      contentItemJson: contentItemJson,
      position: initialPosition ?? const Offset(16, 100),
    );
  }

  void deactivatePip({bool disposePlayer = true}) {
    _logger.d('Deactivating PiP (dispose: $disposePlayer)');
    final oldPlayer = state.player;
    state = PipState.empty;
    if (disposePlayer && oldPlayer != null) {
      try {
        oldPlayer.dispose();
        _logger.d('Player disposed');
      } catch (e) {
        _logger.e('Error disposing player: $e');
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
