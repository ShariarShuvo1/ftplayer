import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class PipState {
  const PipState({
    required this.isActive,
    this.player,
    this.videoController,
    this.videoUrl,
    this.videoTitle,
    this.contentItemJson,
    this.position = const Offset(16, 100),
  });

  final bool isActive;
  final Player? player;
  final VideoController? videoController;
  final String? videoUrl;
  final String? videoTitle;
  final Map<String, dynamic>? contentItemJson;
  final Offset position;

  PipState copyWith({
    bool? isActive,
    Player? player,
    VideoController? videoController,
    String? videoUrl,
    String? videoTitle,
    Map<String, dynamic>? contentItemJson,
    Offset? position,
  }) {
    return PipState(
      isActive: isActive ?? this.isActive,
      player: player ?? this.player,
      videoController: videoController ?? this.videoController,
      videoUrl: videoUrl ?? this.videoUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      contentItemJson: contentItemJson ?? this.contentItemJson,
      position: position ?? this.position,
    );
  }

  static const empty = PipState(isActive: false);
}
