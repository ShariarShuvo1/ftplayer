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
    this.width = 180.0,
    this.height = 100.0,
    this.currentVideoUrl,
    this.currentSeasonNumber,
    this.currentEpisodeNumber,
    this.currentEpisodeId,
    this.currentEpisodeTitle,
  });

  final bool isActive;
  final Player? player;
  final VideoController? videoController;
  final String? videoUrl;
  final String? videoTitle;
  final Map<String, dynamic>? contentItemJson;
  final Offset position;
  final double width;
  final double height;
  final String? currentVideoUrl;
  final int? currentSeasonNumber;
  final int? currentEpisodeNumber;
  final String? currentEpisodeId;
  final String? currentEpisodeTitle;

  PipState copyWith({
    bool? isActive,
    Player? player,
    VideoController? videoController,
    String? videoUrl,
    String? videoTitle,
    Map<String, dynamic>? contentItemJson,
    Offset? position,
    double? width,
    double? height,
    String? currentVideoUrl,
    int? currentSeasonNumber,
    int? currentEpisodeNumber,
    String? currentEpisodeId,
    String? currentEpisodeTitle,
  }) {
    return PipState(
      isActive: isActive ?? this.isActive,
      player: player ?? this.player,
      videoController: videoController ?? this.videoController,
      videoUrl: videoUrl ?? this.videoUrl,
      videoTitle: videoTitle ?? this.videoTitle,
      contentItemJson: contentItemJson ?? this.contentItemJson,
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      currentVideoUrl: currentVideoUrl ?? this.currentVideoUrl,
      currentSeasonNumber: currentSeasonNumber ?? this.currentSeasonNumber,
      currentEpisodeNumber: currentEpisodeNumber ?? this.currentEpisodeNumber,
      currentEpisodeId: currentEpisodeId ?? this.currentEpisodeId,
      currentEpisodeTitle: currentEpisodeTitle ?? this.currentEpisodeTitle,
    );
  }

  static const empty = PipState(isActive: false);
}
