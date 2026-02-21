import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:logger/logger.dart';
import '../../app/theme/app_colors.dart';
import '../../app/router.dart';
import '../../core/utils/vibration_helper.dart';
import '../../state/pip/pip_provider.dart';
import '../../state/settings/vibration_settings_provider.dart';
import '../../state/watch_history/watch_history_provider.dart';
import '../ftp_servers/data/ftp_servers_local_data.dart';
import '../home/data/home_models.dart';
import '../content_details/presentation/content_details_screen.dart';
import '../watch_history/data/watch_history_storage.dart';

class PipOverlay extends ConsumerStatefulWidget {
  const PipOverlay({super.key});

  @override
  ConsumerState<PipOverlay> createState() => _PipOverlayState();
}

class _PipOverlayState extends ConsumerState<PipOverlay>
    with SingleTickerProviderStateMixin {
  final Logger _logger = Logger();
  late Offset _position;
  bool _isDragging = false;
  bool _isResizing = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _positionInitialized = false;
  double _width = 180.0;
  double _height = 100.0;
  static const double _minWidth = 180.0;
  static const double _minHeight = 100.0;
  static const double _maxWidth = 400.0;
  static const double _maxHeight = 225.0;
  bool _isAlignedLeft = true;
  AnimationController? _transitionController;

  @override
  void initState() {
    super.initState();
    _position = const Offset(16, 100);
    _startHideControlsTimer();
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _transitionController?.dispose();
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

  Future<void> _handleFullscreenTap() async {
    try {
      final vibrationSettings = ref.read(vibrationSettingsProvider);
      if (vibrationSettings.enabled && vibrationSettings.vibrateOnPip) {
        VibrationHelper.vibrate(vibrationSettings.strength);
      }

      final pipState = ref.read(pipProvider);
      final contentItemJson = pipState.contentItemJson;

      if (contentItemJson == null) {
        if (mounted) {
          try {
            final storage = ref.read(watchHistoryStorageProvider);
            await storage.flush();
          } catch (e) {
            _logger.e('[PIP Close] Error flushing watch history: $e');
          }
          ref.read(pipProvider.notifier).deactivatePip(disposePlayer: false);
        }
        return;
      }

      final contentItem = ContentItem.fromJson(contentItemJson);

      if (!mounted) {
        return;
      }

      final router = ref.read(goRouterProvider);
      router.push(ContentDetailsScreen.path, extra: contentItem);
    } catch (e) {
      if (mounted) {
        try {
          final storage = ref.read(watchHistoryStorageProvider);
          await storage.flush();
        } catch (e) {
          _logger.e('[PIP Close] Error flushing watch history: $e');
        }
        ref.read(pipProvider.notifier).deactivatePip(disposePlayer: false);
      }
    }
  }

  Future<void> _saveProgressBeforeClose() async {
    final pipState = ref.read(pipProvider);

    if (pipState.player == null || pipState.contentItemJson == null) {
      return;
    }

    try {
      final contentItem = ContentItem.fromJson(pipState.contentItemJson!);
      final currentTime = pipState.player!.state.position.inSeconds.toDouble();
      final duration = pipState.player!.state.duration.inSeconds.toDouble();

      if (duration <= 0) return;

      final server = FtpServersLocalData.getServerByName(
        contentItem.serverName,
      );

      if (server == null) return;

      ref
          .read(watchHistoryNotifierProvider.notifier)
          .updateProgress(
            ftpServerId: server.id,
            serverName: contentItem.serverName,
            serverType: contentItem.serverType,
            contentType: contentItem.contentType ?? 'movie',
            contentId: contentItem.id,
            contentTitle: contentItem.title,
            currentTime: currentTime,
            duration: duration,
            seasonNumber: pipState.currentSeasonNumber,
            episodeNumber: pipState.currentEpisodeNumber,
            episodeId: pipState.currentEpisodeId,
            episodeTitle: pipState.currentEpisodeTitle,
            metadata: {
              'serverName': contentItem.serverName,
              'posterUrl': contentItem.posterUrl,
              'year': contentItem.year,
              'quality': contentItem.quality,
            },
            immediate: true,
          );
    } catch (e) {
      _logger.e('[PIP Close] Error saving progress: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pipState = ref.watch(pipProvider);

    if (!pipState.isActive ||
        pipState.player == null ||
        pipState.videoController == null) {
      _positionInitialized = false;
      return const SizedBox.shrink();
    }

    if (!_positionInitialized) {
      _position = pipState.position;
      _width = pipState.width;
      _height = pipState.height;
      final size = MediaQuery.of(context).size;
      final centerX = _position.dx + _width / 2;
      final screenCenterX = size.width / 2;
      _isAlignedLeft = centerX < screenCenterX;
      _positionInitialized = true;
    }

    final size = MediaQuery.of(context).size;

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanStart: (details) {
          final localPosition = details.localPosition;
          final isCornerHit = _isCornerHit(localPosition);
          setState(() {
            if (isCornerHit) {
              _isResizing = true;
            } else {
              _isDragging = true;
            }
          });
        },
        onPanUpdate: (details) {
          setState(() {
            if (_isResizing) {
              if (_isAlignedLeft) {
                _width = (_width + details.delta.dx).clamp(
                  _minWidth,
                  _maxWidth,
                );
                _height = (_height + details.delta.dy).clamp(
                  _minHeight,
                  _maxHeight,
                );
              } else {
                final oldWidth = _width;
                _width = (_width - details.delta.dx).clamp(
                  _minWidth,
                  _maxWidth,
                );
                _position = Offset(
                  _position.dx + (oldWidth - _width),
                  _position.dy,
                );
                _height = (_height + details.delta.dy).clamp(
                  _minHeight,
                  _maxHeight,
                );
              }
            } else {
              final newX = (_position.dx + details.delta.dx).clamp(
                0.0,
                size.width - _width,
              );
              final newY = (_position.dy + details.delta.dy).clamp(
                0.0,
                size.height - _height,
              );
              _position = Offset(newX, newY);
            }
          });
        },
        onPanEnd: (details) {
          setState(() {
            if (!_isResizing) {
              final centerX = _position.dx + _width / 2;
              final screenCenterX = size.width / 2;
              final snapToLeft = centerX < screenCenterX;
              _isAlignedLeft = snapToLeft;

              final snappedX = snapToLeft ? 16.0 : size.width - _width - 16;
              final clampedY = _position.dy.clamp(0.0, size.height - _height);

              _position = Offset(snappedX, clampedY);
            }
            _isDragging = false;
            _isResizing = false;
          });
          ref
              .read(pipProvider.notifier)
              .updatePositionAndSize(_position, _width, _height);
        },
        onTap: () {
          _toggleControls();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: _width,
          height: _height,
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
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
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
                                  onTap: _handleFullscreenTap,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                _buildControlButton(
                                  icon: Icons.close,
                                  onTap: () async {
                                    final vibrationSettings = ref.read(
                                      vibrationSettingsProvider,
                                    );
                                    if (vibrationSettings.enabled &&
                                        vibrationSettings.vibrateOnPip) {
                                      VibrationHelper.vibrate(
                                        vibrationSettings.strength,
                                      );
                                    }

                                    try {
                                      pipState.player?.pause();
                                    } catch (e) {
                                      _logger.e('Error pausing player: $e');
                                    }
                                    await _saveProgressBeforeClose();
                                    try {
                                      final storage = ref.read(
                                        watchHistoryStorageProvider,
                                      );
                                      await storage.flush();
                                    } catch (e) {
                                      _logger.e(
                                        '[PIP Close] Error flushing watch history: $e',
                                      );
                                    }
                                    ref
                                        .read(pipProvider.notifier)
                                        .deactivatePip(disposePlayer: true);
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
                                    final vibrationSettings = ref.read(
                                      vibrationSettingsProvider,
                                    );
                                    if (vibrationSettings.enabled &&
                                        vibrationSettings.vibrateOnPip) {
                                      VibrationHelper.vibrate(
                                        vibrationSettings.strength,
                                      );
                                    }
                                    try {
                                      if (isPlaying) {
                                        pipState.player?.pause();
                                      } else {
                                        pipState.player?.play();
                                      }
                                      _startHideControlsTimer();
                                    } catch (e) {
                                      _logger.e('Error toggling playback: $e');
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
                        if (_showControls &&
                            _width >= 250 &&
                            pipState.player != null)
                          Positioned(
                            left: 8,
                            right: 8,
                            bottom: 8,
                            child: _buildProgressBar(pipState.player!),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IgnorePointer(child: _buildCornerIndicator()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required dynamic onTap,
    required double size,
    Color? backgroundColor,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (onTap is VoidCallback) {
          onTap();
        } else if (onTap is Future<void> Function()) {
          await onTap();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: size),
      ),
    );
  }

  bool _isCornerHit(Offset localPosition) {
    const cornerSize = 40.0;
    final isTopCorner = localPosition.dy < cornerSize;
    final isBottomCorner = localPosition.dy > _height - cornerSize;
    final isLeftEdge = localPosition.dx < cornerSize;
    final isRightEdge = localPosition.dx > _width - cornerSize;

    if (_isAlignedLeft) {
      return isRightEdge && (isTopCorner || isBottomCorner);
    } else {
      return isLeftEdge && (isTopCorner || isBottomCorner);
    }
  }

  Widget _buildCornerIndicator() {
    const cornerSize = 30.0;
    const borderWidth = 3.0;
    final cornerColor = AppColors.primary.withValues(alpha: 0.6);

    return Stack(
      children: [
        if (_isAlignedLeft) ...[
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: cornerColor, width: borderWidth),
                  right: BorderSide(color: cornerColor, width: borderWidth),
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cornerColor, width: borderWidth),
                  right: BorderSide(color: cornerColor, width: borderWidth),
                ),
                borderRadius: const BorderRadius.only(
                  bottomRight: Radius.circular(12),
                ),
              ),
            ),
          ),
        ],
        if (!_isAlignedLeft) ...[
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: cornerColor, width: borderWidth),
                  left: BorderSide(color: cornerColor, width: borderWidth),
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: cornerSize,
              height: cornerSize,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cornerColor, width: borderWidth),
                  left: BorderSide(color: cornerColor, width: borderWidth),
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(Player player) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      initialData: player.state.position,
      builder: (context, positionSnapshot) {
        return StreamBuilder<Duration>(
          stream: player.stream.duration,
          initialData: player.state.duration,
          builder: (context, durationSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final duration = durationSnapshot.data ?? Duration.zero;
            final progress = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return GestureDetector(
              onTapDown: (details) {
                if (duration.inMilliseconds > 0) {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final localPosition = box.globalToLocal(
                      details.globalPosition,
                    );
                    final containerWidth = box.size.width;
                    final tapPosition = localPosition.dx;
                    final seekPercent = (tapPosition / containerWidth).clamp(
                      0.0,
                      1.0,
                    );
                    final seekPosition = Duration(
                      milliseconds: (duration.inMilliseconds * seekPercent)
                          .round(),
                    );
                    player.seek(seekPosition);
                  }
                }
              },
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Container(
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
