import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:logger/logger.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/config/subtitle_settings.dart';
import '../../../../../core/utils/vibration_helper.dart';
import '../../../../../state/settings/subtitle_settings_provider.dart';
import '../../../../../state/settings/vibration_settings_provider.dart';
import '../../../../../state/settings/video_playback_settings_provider.dart';
import 'media_menu_bottom_sheet.dart';
import 'skip_indicator.dart';
import 'video_surface.dart';

part 'video_player_lifecycle.dart';
part 'video_player_interactions.dart';
part 'video_player_helpers.dart';

abstract class _VideoPlayerBaseState extends ConsumerState<VideoPlayerWidget> {
  final Logger _logger = Logger();
  late Player _player;
  late VideoController _videoController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _showControls = false;
  String? _errorMessage;
  bool _isBuffering = false;
  bool _isDisposing = false;
  bool _ownershipTransferred = false;
  bool _isFullscreen = false;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  Timer? _controlsTimer;
  Timer? _progressTimer;
  Duration _lastPosition = Duration.zero;
  final Duration _positionUpdateThrottle = const Duration(milliseconds: 200);
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  Duration _lastProgressReportPosition = Duration.zero;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier(
    Duration.zero,
  );
  bool _isDraggingSlider = false;
  double _dragPositionMillis = 0.0;
  bool _isSeeking = false;
  bool _showForwardIndicator = false;
  bool _showReplayIndicator = false;
  Timer? _forwardIndicatorTimer;
  Timer? _replayIndicatorTimer;
  int _cumulativeSkipSeconds = 0;
  bool _isHoldingForSpeed = false;
  Timer? _speedTagAutoHideTimer;
  int? _selectedSubtitleIndex;
  int? _selectedAudioIndex;
  bool _hasAppliedInitialSeek = false;
  bool _isPlayerReady = false;
  Timer? _initializationCheckTimer;
  double _pullUpOffset = 0.0;
  bool _isPullingUp = false;
  final double _fullscreenTriggerThreshold = 105.0;
  double _initialDragY = 0.0;
  bool _isDraggingDown = false;
  double _pullDownOffset = 0.0;
  bool _isPullingDownFromFullscreen = false;
  final double _fullscreenExitThreshold = 120.0;
  bool _isLandscapeLeft = true;
  Timer? _singleTapTimer;
  double _currentPlaybackSpeed = 1.0;
  SubtitleSettings _subtitleSettings = SubtitleSettings.defaults;
  bool _hasTriggeredAutoAdvance = false;

  Player? get player => _player;
  VideoController? get videoController => _videoController;
  bool get isFullscreen => _isFullscreen;
  Duration get currentPosition => _lastPosition;

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls && _isPlaying) {
      _startControlsTimer();
    }
  }

  void _startControlsTimer() {
    _cancelControlsTimer();
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _cancelControlsTimer() {
    _controlsTimer?.cancel();
    _controlsTimer = null;
  }

  void _startProgressTimer() {
    _cancelProgressTimer();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _notifyProgressUpdate();
    });
  }

  void _cancelProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _cancelIndicatorTimers() {
    _forwardIndicatorTimer?.cancel();
    _replayIndicatorTimer?.cancel();
    _forwardIndicatorTimer = null;
    _replayIndicatorTimer = null;
  }

  void _notifyProgressUpdate() {
    if (widget.onProgressUpdate != null && _duration.inSeconds > 0) {
      widget.onProgressUpdate!(
        _lastPosition.inSeconds.toDouble(),
        _duration.inSeconds.toDouble(),
      );
    }
  }

  Future<void> _updateSubtitleSettings(SubtitleSettings settings) async {
    setState(() {
      _subtitleSettings = settings;
    });
    await ref.read(subtitleSettingsProvider.notifier).updateSettings(settings);
  }

  void _handlePreviousEpisode() {
    if (!widget.canGoToPreviousEpisode) {
      return;
    }
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled &&
        vibrationSettings.vibrateOnVideoController) {
      VibrationHelper.vibrate(vibrationSettings.strength);
    }
    widget.onPreviousEpisode?.call();
  }

  void _handleNextEpisode() {
    if (!widget.canGoToNextEpisode) {
      return;
    }
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled &&
        vibrationSettings.vibrateOnVideoController) {
      VibrationHelper.vibrate(vibrationSettings.strength);
    }
    widget.onNextEpisode?.call();
  }
}

class VideoPlayerWidget extends ConsumerStatefulWidget {
  const VideoPlayerWidget({
    required this.videoUrl,
    this.autoPlay = true,
    this.initialPosition,
    this.showEpisodeControls = false,
    this.canGoToPreviousEpisode = false,
    this.canGoToNextEpisode = false,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onFullscreenChanged,
    this.onProgressUpdate,
    this.onRequestImmediateSave,
    this.forceHideControls = false,
    super.key,
  }) : player = null,
       videoController = null,
       _isFromExisting = false;

  const VideoPlayerWidget.fromExisting({
    required this.player,
    required this.videoController,
    this.showEpisodeControls = false,
    this.canGoToPreviousEpisode = false,
    this.canGoToNextEpisode = false,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onFullscreenChanged,
    this.onProgressUpdate,
    this.onRequestImmediateSave,
    this.forceHideControls = false,
    super.key,
  }) : videoUrl = '',
       autoPlay = false,
       initialPosition = null,
       _isFromExisting = true;

  final String videoUrl;
  final bool autoPlay;
  final Duration? initialPosition;
  final Player? player;
  final VideoController? videoController;
  final bool showEpisodeControls;
  final bool canGoToPreviousEpisode;
  final bool canGoToNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final bool _isFromExisting;
  final bool forceHideControls;
  final void Function(bool)? onFullscreenChanged;
  final void Function(double currentTime, double duration)? onProgressUpdate;
  final void Function()? onRequestImmediateSave;

  @override
  ConsumerState<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends _VideoPlayerBaseState
    with
        _VideoPlayerLifecycleMixin,
        _VideoPlayerInteractionMixin,
        _VideoPlayerHelpersMixin {
  @override
  void initState() {
    super.initState();
    _hasAppliedInitialSeek = false;
    _isPlayerReady = false;
    _loadSubtitleSettings();
    if (widget._isFromExisting &&
        widget.player != null &&
        widget.videoController != null) {
      _player = widget.player!;
      _videoController = widget.videoController!;
      _setupExistingPlayer();
    } else {
      _initializePlayer();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        width: double.infinity,
        height: 250,
        color: AppColors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load video',
                style: TextStyle(color: AppColors.textHigh, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _errorMessage ?? 'Unknown error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textLow,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        width: double.infinity,
        height: 250,
        color: AppColors.black,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final child = LayoutBuilder(
      builder: (context, constraints) {
        final pullUpProgress = _getPullUpProgress();
        final pullDownProgress = _getPullDownProgress();
        final videoScale = _isFullscreen
            ? 1.0 - (pullDownProgress * 0.3)
            : 1.0 + (pullUpProgress * 0.3);
        final containerOpacity = _isFullscreen && _isPullingDownFromFullscreen
            ? 1.0 - pullDownProgress
            : 1.0;

        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTapDown: (details) => _handleSingleTap(details, constraints),
              onDoubleTapDown: (details) =>
                  _handleDoubleTap(details, constraints),
              onLongPressStart: (_) => _handleLongPressStart(),
              onLongPressEnd: (_) => _handleLongPressEnd(),
              child: Container(
                width: double.infinity,
                height: _isFullscreen
                    ? MediaQuery.of(context).size.height
                    : 250,
                color: AppColors.black.withValues(alpha: containerOpacity),
                child: Stack(
                  children: [
                    if (_isFullscreen)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Transform.scale(
                          scale: videoScale,
                          alignment: Alignment.bottomCenter,
                          child: VideoSurface(
                            key: const ValueKey('video_surface'),
                            controller: _videoController,
                            subtitleSettings: _subtitleSettings,
                          ),
                        ),
                      )
                    else
                      Center(
                        child: Transform.scale(
                          scale: videoScale,
                          alignment: Alignment.bottomCenter,
                          child: VideoSurface(
                            key: const ValueKey('video_surface'),
                            controller: _videoController,
                            subtitleSettings: _subtitleSettings,
                          ),
                        ),
                      ),
                    if (_isBuffering && !_isSeeking)
                      Container(
                        color: Colors.black.withValues(alpha: 0.5),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _isFullscreen
                          ? MediaQuery.of(context).size.width * 0.3
                          : constraints.maxWidth * 0.3,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _showReplayIndicator ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: AnimatedScale(
                            scale: _showReplayIndicator ? 1.0 : 0.9,
                            duration: const Duration(milliseconds: 150),
                            child: SkipIndicator(
                              isForward: false,
                              label: '${_cumulativeSkipSeconds.abs()}s',
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: _isFullscreen
                          ? MediaQuery.of(context).size.width * 0.3
                          : constraints.maxWidth * 0.3,
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          opacity: _showForwardIndicator ? 1 : 0,
                          duration: const Duration(milliseconds: 150),
                          child: AnimatedScale(
                            scale: _showForwardIndicator ? 1.0 : 0.9,
                            duration: const Duration(milliseconds: 150),
                            child: SkipIndicator(
                              isForward: true,
                              label: '${_cumulativeSkipSeconds.abs()}s',
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_isHoldingForSpeed)
                      Positioned(
                        top: 56,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _isHoldingForSpeed ? 1 : 0,
                            duration: const Duration(milliseconds: 150),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.double_arrow,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${ref.watch(videoPlaybackSettingsProvider).holdToSpeedRate}x',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_showControls &&
                        !_isBuffering &&
                        !widget.forceHideControls)
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                    if (_showControls &&
                        !_isBuffering &&
                        !widget.forceHideControls)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isFullscreen)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.screen_rotation,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                  onPressed: _toggleLandscapeSide,
                                ),
                              ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.settings,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                onPressed: () {
                                  final vibrationSettings = ref.read(
                                    vibrationSettingsProvider,
                                  );
                                  if (vibrationSettings.enabled &&
                                      vibrationSettings
                                          .vibrateOnContentDetailsOthers) {
                                    VibrationHelper.vibrate(
                                      vibrationSettings.strength,
                                    );
                                  }
                                  _showMediaMenu(context);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_showControls &&
                        !_isBuffering &&
                        !widget.forceHideControls)
                      Align(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showEpisodeControls)
                              IconButton(
                                icon: Icon(
                                  Icons.skip_previous,
                                  color: widget.canGoToPreviousEpisode
                                      ? AppColors.primary
                                      : AppColors.textLow,
                                  size: 30,
                                ),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                onPressed: widget.canGoToPreviousEpisode
                                    ? _handlePreviousEpisode
                                    : null,
                              ),
                            if (widget.showEpisodeControls)
                              const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: AppColors.primary,
                                size: 42,
                              ),
                              iconSize: 52,
                              padding: const EdgeInsets.all(8),
                              onPressed: _togglePlayPause,
                            ),
                            if (widget.showEpisodeControls)
                              const SizedBox(width: 8),
                            if (widget.showEpisodeControls)
                              IconButton(
                                icon: Icon(
                                  Icons.skip_next,
                                  color: widget.canGoToNextEpisode
                                      ? AppColors.primary
                                      : AppColors.textLow,
                                  size: 30,
                                ),
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(),
                                onPressed: widget.canGoToNextEpisode
                                    ? _handleNextEpisode
                                    : null,
                              ),
                          ],
                        ),
                      ),
                    if (_showControls &&
                        !_isBuffering &&
                        !widget.forceHideControls)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              children: [
                                ValueListenableBuilder<Duration>(
                                  valueListenable: _positionNotifier,
                                  builder: (_, value, _) {
                                    return Text(
                                      _formatDuration(value),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                            overlayRadius: 10,
                                          ),
                                      activeTrackColor: AppColors.primary,
                                      inactiveTrackColor: Colors.white
                                          .withValues(alpha: 0.3),
                                      thumbColor: AppColors.primary,
                                      overlayColor: AppColors.primary
                                          .withValues(alpha: 0.2),
                                    ),
                                    child: Slider(
                                      value: _duration.inMilliseconds > 0
                                          ? (_isDraggingSlider
                                                    ? _dragPositionMillis
                                                    : _positionNotifier
                                                          .value
                                                          .inMilliseconds
                                                          .toDouble())
                                                .clamp(
                                                  0.0,
                                                  _duration.inMilliseconds
                                                      .toDouble(),
                                                )
                                          : 0.0,
                                      min: 0.0,
                                      max: _duration.inMilliseconds > 0
                                          ? _duration.inMilliseconds.toDouble()
                                          : 1.0,
                                      onChangeStart: (value) {
                                        _isDraggingSlider = true;
                                        _dragPositionMillis = value;
                                      },
                                      onChanged: (value) {
                                        _dragPositionMillis = value;
                                      },
                                      onChangeEnd: (value) async {
                                        if (_isSeeking) {
                                          return;
                                        }
                                        _isDraggingSlider = false;
                                        _isSeeking = true;
                                        final target = Duration(
                                          milliseconds: value.toInt(),
                                        );
                                        try {
                                          await _player.seek(target);
                                          await Future.delayed(
                                            const Duration(milliseconds: 300),
                                          );
                                        } catch (_) {
                                        } finally {
                                          _isSeeking = false;
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDuration(_duration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: Icon(
                                    _isFullscreen
                                        ? Icons.fullscreen_exit
                                        : Icons.fullscreen,
                                    color: AppColors.primary,
                                    size: 22,
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  constraints: const BoxConstraints(),
                                  onPressed: _toggleFullscreen,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_isFullscreen)
              Positioned.fill(
                child: Listener(
                  onPointerDown: (event) {
                    if (!_isFullscreen) return;
                    _initialDragY = event.position.dy;
                    setState(() {
                      _isPullingDownFromFullscreen = false;
                      _pullDownOffset = 0.0;
                    });
                  },
                  onPointerMove: (event) {
                    if (!_isFullscreen) return;

                    final currentY = event.position.dy;
                    final totalDelta = currentY - _initialDragY;

                    if (!_isPullingDownFromFullscreen && totalDelta > 10) {
                      setState(() {
                        _isPullingDownFromFullscreen = true;
                      });
                    }

                    if (_isPullingDownFromFullscreen) {
                      setState(() {
                        if (totalDelta > 0) {
                          _pullDownOffset = totalDelta.clamp(
                            0.0,
                            _fullscreenExitThreshold,
                          );
                        } else {
                          _pullDownOffset = 0.0;
                        }
                      });
                    }
                  },
                  onPointerUp: (event) {
                    if (!_isFullscreen) return;

                    if (_isPullingDownFromFullscreen &&
                        _pullDownOffset >= _fullscreenExitThreshold) {
                      final vibrationSettings = ref.read(
                        vibrationSettingsProvider,
                      );
                      if (vibrationSettings.enabled &&
                          vibrationSettings.vibrateOnGestures) {
                        VibrationHelper.vibrate(vibrationSettings.strength);
                      }
                      _toggleFullscreen();
                    }

                    setState(() {
                      _isPullingDownFromFullscreen = false;
                      _pullDownOffset = 0.0;
                    });
                  },
                  onPointerCancel: (event) {
                    if (!_isFullscreen) return;
                    setState(() {
                      _isPullingDownFromFullscreen = false;
                      _pullDownOffset = 0.0;
                    });
                  },
                  behavior: HitTestBehavior.translucent,
                  child: IgnorePointer(
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            if (_isFullscreen && _isPullingDownFromFullscreen)
              Positioned.fill(
                child: GestureDetector(
                  onVerticalDragUpdate: (_) {},
                  onVerticalDragEnd: (_) {},
                  behavior: HitTestBehavior.opaque,
                  child: IgnorePointer(
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            if (!_isFullscreen)
              Positioned.fill(
                child: Listener(
                  onPointerDown: (event) {
                    if (_isFullscreen) return;
                    _initialDragY = event.position.dy;
                    _isDraggingDown = false;
                    setState(() {
                      _isPullingUp = false;
                      _pullUpOffset = 0.0;
                    });
                  },
                  onPointerMove: (event) {
                    if (_isFullscreen) return;

                    final currentY = event.position.dy;
                    final totalDelta = _initialDragY - currentY;

                    if (!_isPullingUp && !_isDraggingDown) {
                      if (totalDelta > 10) {
                        setState(() {
                          _isPullingUp = true;
                        });
                      } else if (totalDelta < -10) {
                        _isDraggingDown = true;
                      }
                    }

                    if (_isPullingUp && !_isDraggingDown) {
                      setState(() {
                        if (totalDelta > 0) {
                          _pullUpOffset = totalDelta.clamp(
                            0.0,
                            _fullscreenTriggerThreshold,
                          );
                        } else {
                          _pullUpOffset = 0.0;
                        }
                      });
                    }
                  },
                  onPointerUp: (event) {
                    if (_isFullscreen) return;

                    if (_isPullingUp &&
                        _pullUpOffset >= _fullscreenTriggerThreshold) {
                      final vibrationSettings = ref.read(
                        vibrationSettingsProvider,
                      );
                      if (vibrationSettings.enabled &&
                          vibrationSettings.vibrateOnGestures) {
                        VibrationHelper.vibrate(vibrationSettings.strength);
                      }
                      _toggleFullscreen();
                    }

                    setState(() {
                      _isPullingUp = false;
                      _pullUpOffset = 0.0;
                      _isDraggingDown = false;
                    });
                  },
                  onPointerCancel: (event) {
                    if (_isFullscreen) return;
                    setState(() {
                      _isPullingUp = false;
                      _pullUpOffset = 0.0;
                      _isDraggingDown = false;
                    });
                  },
                  behavior: HitTestBehavior.translucent,
                  child: IgnorePointer(
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            if (!_isFullscreen && _isPullingUp)
              Positioned.fill(
                child: GestureDetector(
                  onVerticalDragUpdate: (_) {},
                  onVerticalDragEnd: (_) {},
                  behavior: HitTestBehavior.opaque,
                  child: IgnorePointer(
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (_isFullscreen) {
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: EdgeInsets.zero,
          viewPadding: EdgeInsets.zero,
          viewInsets: EdgeInsets.zero,
        ),
        child: child,
      );
    }

    return child;
  }
}
