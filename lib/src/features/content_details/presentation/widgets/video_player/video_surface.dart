import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../../../../core/config/subtitle_settings.dart';

class VideoSurface extends StatefulWidget {
  const VideoSurface({
    required this.controller,
    required this.subtitleSettings,
    super.key,
  });

  final VideoController controller;
  final SubtitleSettings subtitleSettings;

  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Video(
      controller: widget.controller,
      controls: NoVideoControls,
      subtitleViewConfiguration: widget.subtitleSettings.toViewConfiguration(),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
