import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../app/theme/app_colors.dart';
import '../../app/router.dart';
import '../../state/pip/pip_provider.dart';
import '../home/data/home_models.dart';
import '../content_details/presentation/content_details_screen.dart';

final _logger = Logger();

class PipOverlay extends ConsumerStatefulWidget {
  const PipOverlay({super.key});

  @override
  ConsumerState<PipOverlay> createState() => _PipOverlayState();
}

class _PipOverlayState extends ConsumerState<PipOverlay> {
  Offset _position = const Offset(16, 100);
  bool _isDragging = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls) {
        _startHideControlsTimer();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final pipState = ref.watch(pipProvider);

    _logger.d(
      '🎬 PiP build: isActive=${pipState.isActive}, player=${pipState.player != null}, controller=${pipState.videoController != null}',
    );

    if (!pipState.isActive ||
        pipState.player == null ||
        pipState.videoController == null) {
      _logger.d('🎬 PiP inactive or null references, hiding overlay');
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    const pipWidth = 180.0;
    const pipHeight = 100.0;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() {
            _isDragging = true;
          });
        },
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position.dx + details.delta.dx).clamp(0, size.width - pipWidth),
              (_position.dy + details.delta.dy).clamp(
                0,
                size.height - pipHeight,
              ),
            );
          });
        },
        onPanEnd: (details) {
          setState(() {
            _isDragging = false;
            final snapToLeft = _position.dx < (size.width - pipWidth) / 2;
            _position = Offset(
              snapToLeft ? 16 : size.width - pipWidth - 16,
              _position.dy,
            );
          });
          ref.read(pipProvider.notifier).updatePosition(_position);
        },
        onTap: () {
          _toggleControls();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: pipWidth,
          height: pipHeight,
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                Video(
                  controller: pipState.videoController!,
                  controls: NoVideoControls,
                ),
                if (_showControls)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.6),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.6),
                        ],
                      ),
                    ),
                  ),
                if (_showControls)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Row(
                      children: [
                        _buildControlButton(
                          icon: Icons.fullscreen,
                          onTap: () {
                            _logger.d('Fullscreen button tapped');

                            final contentItemJson = pipState.contentItemJson;
                            if (contentItemJson == null) {
                              _logger.w('No content item, deactivating PiP');
                              ref.read(pipProvider.notifier).deactivatePip();
                              return;
                            }

                            try {
                              final contentItem = ContentItem.fromJson(
                                contentItemJson,
                              );
                              final router = ref.read(goRouterProvider);

                              router.push(
                                ContentDetailsScreen.path,
                                extra: contentItem,
                              );
                            } catch (e) {
                              _logger.e(
                                'Error navigating to content details: $e',
                              );
                              ref.read(pipProvider.notifier).deactivatePip();
                            }
                          },
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        _buildControlButton(
                          icon: Icons.close,
                          onTap: () {
                            try {
                              pipState.player?.pause();
                            } catch (e) {
                              _logger.w('Error pausing player on close: $e');
                            }
                            ref.read(pipProvider.notifier).deactivatePip();
                          },
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                if (_showControls && pipState.player != null)
                  Center(
                    child: StreamBuilder<bool>(
                      stream: pipState.player!.stream.playing,
                      initialData: pipState.player!.state.playing,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data ?? false;
                        return GestureDetector(
                          onTap: () {
                            _logger.d(
                              '🎬 Play/pause tapped: isPlaying=$isPlaying',
                            );
                            _logger.d(
                              '🎬 Player valid: ${pipState.player != null}',
                            );
                            try {
                              if (isPlaying) {
                                _logger.d('🎬 Attempting to pause...');
                                pipState.player?.pause();
                                _logger.d('🎬 Pause successful');
                              } else {
                                _logger.d('🎬 Attempting to play...');
                                pipState.player?.play();
                                _logger.d('🎬 Play successful');
                              }
                              _startHideControlsTimer();
                            } catch (e) {
                              _logger.e('🎬 PLAYER CONTROL ERROR: $e');
                            }
                          },
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: AppColors.primary,
                            size: 48,
                          ),
                        );
                      },
                    ),
                  ),
                if (_isDragging)
                  Container(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    child: const Center(
                      child: Icon(
                        Icons.drag_indicator,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
