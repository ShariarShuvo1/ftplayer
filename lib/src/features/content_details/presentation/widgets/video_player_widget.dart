import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:logger/logger.dart';

import '../../../../app/theme/app_colors.dart';

class VideoPlayerWidget extends StatefulWidget {
  const VideoPlayerWidget({
    required this.videoUrl,
    this.autoPlay = true,
    this.initialPosition,
    this.onFullscreenChanged,
    this.onProgressUpdate,
    super.key,
  }) : player = null,
       videoController = null,
       _isFromExisting = false;

  const VideoPlayerWidget.fromExisting({
    required this.player,
    required this.videoController,
    this.onFullscreenChanged,
    this.onProgressUpdate,
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
  final bool _isFromExisting;
  final void Function(bool)? onFullscreenChanged;
  final void Function(double currentTime, double duration)? onProgressUpdate;

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _SkipIndicator extends StatelessWidget {
  const _SkipIndicator({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 48),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoSurface extends StatefulWidget {
  const _VideoSurface({required super.key, required this.controller});

  final VideoController controller;

  @override
  State<_VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<_VideoSurface>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Video(controller: widget.controller, controls: NoVideoControls);
  }

  @override
  bool get wantKeepAlive => true;
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
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
  bool _isHoldingForSpeed = false;
  final double _normalPlaybackSpeed = 1.0;
  int? _selectedSubtitleIndex;
  int? _selectedAudioIndex;
  bool _hasAppliedInitialSeek = false;
  bool _isPlayerReady = false;
  Timer? _initializationCheckTimer;

  Player? get player => _player;
  VideoController? get videoController => _videoController;
  bool get isFullscreen => _isFullscreen;
  Duration get currentPosition => _lastPosition;

  @override
  void initState() {
    super.initState();
    _hasAppliedInitialSeek = false;
    _isPlayerReady = false;
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
  void didUpdateWidget(VideoPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    final urlChanged =
        !widget._isFromExisting &&
        oldWidget.videoUrl != widget.videoUrl &&
        widget.videoUrl.isNotEmpty &&
        _isInitialized;
    final positionChanged = oldWidget.initialPosition != widget.initialPosition;

    if (urlChanged) {
      _hasAppliedInitialSeek = false;
      _isPlayerReady = false;
      _reloadVideo();
    }

    if (positionChanged) {
      _hasAppliedInitialSeek = false;
      if (!urlChanged) {
        _waitForPlayerReadyAndSeek();
      }
    }
  }

  Future<void> _reloadVideo() async {
    try {
      _hasError = false;
      _errorMessage = null;
      _lastPosition = Duration.zero;
      _positionNotifier.value = Duration.zero;
      _duration = Duration.zero;
      _isPlaying = false;
      _isBuffering = false;

      final media = Media(
        widget.videoUrl,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 11; Mobile)',
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip, deflate',
        },
      );
      await _player.open(media);

      setState(() {
        _hasError = false;
      });

      _waitForPlayerReadyAndSeek();

      if (widget.autoPlay) {
        await _player.play();
        WakelockPlus.enable();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _setupExistingPlayer() async {
    try {
      _player.stream.error.listen((error) {
        if (mounted && !_isDisposing) {
          setState(() {
            _hasError = true;
            _errorMessage = error;
          });
        }
      });

      _player.stream.buffering.listen((buffering) {
        if (mounted && !_isDisposing) {
          setState(() {
            _isBuffering = buffering;
          });
        }
      });

      _player.stream.duration.listen((duration) {
        if (mounted && !_isDisposing) {
          setState(() {
            _duration = duration;
          });
        }
      });

      _player.stream.position.listen((position) {
        if (mounted && !_isDisposing) {
          _lastPosition = position;

          final progressDiff =
              (position.inSeconds - _lastProgressReportPosition.inSeconds)
                  .abs();
          if (progressDiff > 3) {
            _lastProgressReportPosition = position;
            _notifyProgressUpdate();
          }

          final now = DateTime.now();
          if (now.difference(_lastUiUpdate) >= _positionUpdateThrottle) {
            _lastUiUpdate = now;
            _positionNotifier.value = position;
          }
        }
      });

      _player.stream.playing.listen((playing) {
        if (mounted && !_isDisposing) {
          setState(() {
            _isPlaying = playing;
          });
          if (playing) {
            WakelockPlus.enable();
            if (_showControls) {
              _startControlsTimer();
            }
            _startProgressTimer();
          } else {
            WakelockPlus.disable();
            _cancelControlsTimer();
            _cancelProgressTimer();
          }
        }
      });

      setState(() {
        _isInitialized = true;
        _duration = _player.state.duration;
        _isPlaying = _player.state.playing;
      });
      _lastPosition = _player.state.position;
      _positionNotifier.value = _lastPosition;
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _initializePlayer() async {
    try {
      _player = Player();
      _videoController = VideoController(_player);

      _player.stream.error.listen((error) {
        if (mounted && !_isDisposing) {
          _logger.e('Player error: $error');
          setState(() {
            _hasError = true;
            _errorMessage = error;
          });
        }
      });

      _player.stream.buffering.listen((buffering) {
        if (mounted && !_isDisposing) {
          setState(() {
            _isBuffering = buffering;
          });
        }
      });

      _player.stream.position.listen((position) {
        if (mounted && !_isDisposing) {
          _lastPosition = position;
          final now = DateTime.now();
          if (now.difference(_lastUiUpdate) >= _positionUpdateThrottle) {
            _lastUiUpdate = now;
            _positionNotifier.value = position;
          }
        }
      });

      _player.stream.duration.listen((duration) {
        if (mounted && !_isDisposing) {
          if (duration > Duration.zero && !_isPlayerReady) {
            _isPlayerReady = true;
            _waitForPlayerReadyAndSeek();
          }
          setState(() {
            _duration = duration;
          });
        }
      });

      _player.stream.playing.listen((playing) {
        if (mounted && !_isDisposing) {
          setState(() {
            _isPlaying = playing;
          });
          if (playing) {
            _startProgressTimer();
          } else {
            _cancelProgressTimer();
          }
        }
      });

      await _player.open(
        Media(
          widget.videoUrl,
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 11; Mobile)',
            'Connection': 'keep-alive',
            'Accept-Encoding': 'gzip, deflate',
          },
        ),
        play: false,
      );

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        _waitForPlayerReadyAndSeek();

        if (widget.autoPlay) {
          await _player.play();
          WakelockPlus.enable();
        }
      }
    } catch (e) {
      _logger.e('Error initializing player: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _waitForPlayerReadyAndSeek() {
    if (_hasAppliedInitialSeek) {
      return;
    }

    if (widget.initialPosition == null ||
        widget.initialPosition!.inSeconds <= 0) {
      return;
    }

    if (!_isPlayerReady || _duration <= Duration.zero) {
      _initializationCheckTimer?.cancel();
      _initializationCheckTimer = Timer(const Duration(milliseconds: 500), () {
        _waitForPlayerReadyAndSeek();
      });
      return;
    }

    _initializationCheckTimer?.cancel();
    _applyInitialSeek();
  }

  Future<void> _applyInitialSeek() async {
    if (_hasAppliedInitialSeek) {
      return;
    }
    if (widget.initialPosition == null ||
        widget.initialPosition!.inSeconds <= 0) {
      return;
    }

    try {
      _hasAppliedInitialSeek = true;
      final seekPosition = widget.initialPosition!;
      await _player.seek(seekPosition);
      _positionNotifier.value = seekPosition;
      _lastPosition = seekPosition;
    } catch (e) {
      _logger.e('Error applying initial seek: $e');
      _hasAppliedInitialSeek = false;
    }
  }

  @override
  void dispose() {
    _initializationCheckTimer?.cancel();
    _cancelControlsTimer();
    _cancelProgressTimer();
    _cancelIndicatorTimers();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
    _isDisposing = true;
    if (!_ownershipTransferred) {
      try {
        _player.dispose();
      } catch (e) {
        // Ignore disposal errors
      }
      WakelockPlus.disable();
    }
    _positionNotifier.dispose();
    super.dispose();
  }

  void transferOwnership() {
    _ownershipTransferred = true;
  }

  void _togglePlayPause() {
    if (_isPlaying) {
      _player.pause();
      WakelockPlus.disable();
    } else {
      _player.play();
      WakelockPlus.enable();
    }
  }

  void _seekBy(Duration offset) {
    final target = _lastPosition + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);
    _player.seek(clamped);
    _positionNotifier.value = clamped;
  }

  void _showSkipOverlay({required bool forward}) {
    if (forward) {
      _forwardIndicatorTimer?.cancel();
      setState(() {
        _showForwardIndicator = true;
      });
      _forwardIndicatorTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _showForwardIndicator = false;
          });
        }
      });
    } else {
      _replayIndicatorTimer?.cancel();
      setState(() {
        _showReplayIndicator = true;
      });
      _replayIndicatorTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          setState(() {
            _showReplayIndicator = false;
          });
        }
      });
    }
  }

  void _handleDoubleTap(TapDownDetails details, BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final dx = details.localPosition.dx;
    final leftBound = width * 0.3;
    final rightBound = width * 0.7;

    if (dx <= leftBound) {
      _seekBy(const Duration(seconds: -10));
      _showSkipOverlay(forward: false);
      return;
    }

    if (dx >= rightBound) {
      _seekBy(const Duration(seconds: 10));
      _showSkipOverlay(forward: true);
      return;
    }
  }

  void _handleSingleTap(TapDownDetails details, BoxConstraints constraints) {
    final height = constraints.maxHeight;
    final dy = details.localPosition.dy;
    const bottomInteractionSafeHeight = 120.0;

    if (_showControls && dy >= height - bottomInteractionSafeHeight) {
      return;
    }

    if (!_showControls) {
      _toggleControls();
    }
  }

  Future<void> _handleLongPressStart() async {
    if (!_isPlaying) return;

    setState(() {
      _isHoldingForSpeed = true;
    });

    await _player.setRate(2.0);
  }

  Future<void> _handleLongPressEnd() async {
    setState(() {
      _isHoldingForSpeed = false;
    });

    await _player.setRate(_normalPlaybackSpeed);
  }

  Future<void> _toggleFullscreen() async {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    widget.onFullscreenChanged?.call(_isFullscreen);

    if (_isFullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
    }
  }

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
    _progressTimer = Timer.periodic(const Duration(seconds: 10), (_) {
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }

  void _showMediaMenu(BuildContext context) {
    int? currentSubtitleIndex;
    int? currentAudioIndex;

    final currentSubtitleTrack = _player.state.track.subtitle;
    if (currentSubtitleTrack.id.isNotEmpty) {
      currentSubtitleIndex = _player.state.tracks.subtitle.indexWhere(
        (track) => track.id == currentSubtitleTrack.id,
      );
      if (currentSubtitleIndex == -1) {
        currentSubtitleIndex = null;
      }
    }

    final currentAudioTrack = _player.state.track.audio;
    if (currentAudioTrack.id.isNotEmpty) {
      currentAudioIndex = _player.state.tracks.audio.indexWhere(
        (track) => track.id == currentAudioTrack.id,
      );
      if (currentAudioIndex == -1) {
        currentAudioIndex = null;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _MediaMenuBottomSheet(
        player: _player,
        selectedSubtitleIndex: currentSubtitleIndex ?? _selectedSubtitleIndex,
        selectedAudioIndex: currentAudioIndex ?? _selectedAudioIndex,
        onSubtitleChanged: (index) {
          setState(() {
            _selectedSubtitleIndex = index;
          });
          if (index == -1) {
            _player.setSubtitleTrack(SubtitleTrack('', '', ''));
          } else if (index >= 0 &&
              index < _player.state.tracks.subtitle.length) {
            _player.setSubtitleTrack(_player.state.tracks.subtitle[index]);
          }
        },
        onAudioChanged: (index) {
          setState(() {
            _selectedAudioIndex = index;
          });
          if (index >= 0 && index < _player.state.tracks.audio.length) {
            _player.setAudioTrack(_player.state.tracks.audio[index]);
          }
        },
      ),
    );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) => _handleSingleTap(details, constraints),
          onDoubleTapDown: (details) => _handleDoubleTap(details, constraints),
          onLongPressStart: (_) => _handleLongPressStart(),
          onLongPressEnd: (_) => _handleLongPressEnd(),
          child: Container(
            width: double.infinity,
            height: _isFullscreen ? MediaQuery.of(context).size.height : 250,
            color: AppColors.black,
            child: Stack(
              children: [
                Center(
                  child: _VideoSurface(
                    key: const ValueKey('video_surface'),
                    controller: _videoController,
                  ),
                ),
                if (_isBuffering)
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
                        child: _SkipIndicator(
                          icon: Icons.replay_10,
                          label: '10s',
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
                        child: _SkipIndicator(
                          icon: Icons.forward_10,
                          label: '10s',
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
                              const Text(
                                '2x',
                                style: TextStyle(
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
                if (_showControls && !_isBuffering)
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
                if (_showControls && !_isBuffering)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(),
                      onPressed: () => _showMediaMenu(context),
                    ),
                  ),
                if (_showControls && !_isBuffering)
                  Positioned.fill(
                    child: Center(
                      child: IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: AppColors.primary,
                          size: 42,
                        ),
                        iconSize: 52,
                        padding: const EdgeInsets.all(8),
                        onPressed: _togglePlayPause,
                      ),
                    ),
                  ),
                if (_showControls && !_isBuffering)
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
                                  overlayShape: const RoundSliderOverlayShape(
                                    overlayRadius: 10,
                                  ),
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: Colors.white.withValues(
                                    alpha: 0.3,
                                  ),
                                  thumbColor: AppColors.primary,
                                  overlayColor: AppColors.primary.withValues(
                                    alpha: 0.2,
                                  ),
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
        );
      },
    );
  }
}

class _MediaMenuBottomSheet extends StatefulWidget {
  const _MediaMenuBottomSheet({
    required this.player,
    this.selectedSubtitleIndex,
    this.selectedAudioIndex,
    required this.onSubtitleChanged,
    required this.onAudioChanged,
  });

  final Player player;
  final int? selectedSubtitleIndex;
  final int? selectedAudioIndex;
  final Function(int) onSubtitleChanged;
  final Function(int) onAudioChanged;

  @override
  State<_MediaMenuBottomSheet> createState() => _MediaMenuBottomSheetState();
}

class _MediaMenuBottomSheetState extends State<_MediaMenuBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.black,
              border: Border(
                bottom: BorderSide(color: AppColors.outline, width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary, width: 1.5),
              ),
              dividerColor: Colors.transparent,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textMid,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              tabs: const [
                Tab(
                  height: 32,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Subtitles'),
                  ),
                ),
                Tab(
                  height: 32,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Audio'),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: TabBarView(
              controller: _tabController,
              children: [
                _SubtitlesTab(
                  player: widget.player,
                  selectedIndex: widget.selectedSubtitleIndex,
                  onSubtitleChanged: widget.onSubtitleChanged,
                ),
                _AudioTracksTab(
                  player: widget.player,
                  selectedIndex: widget.selectedAudioIndex,
                  onAudioChanged: widget.onAudioChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubtitlesTab extends StatelessWidget {
  const _SubtitlesTab({
    required this.player,
    this.selectedIndex,
    required this.onSubtitleChanged,
  });

  final Player player;
  final int? selectedIndex;
  final Function(int) onSubtitleChanged;

  @override
  Widget build(BuildContext context) {
    final subtitles = player.state.tracks.subtitle;

    if (subtitles.isEmpty) {
      return const Center(
        child: Text(
          'No subtitles available',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    final validSubtitles = subtitles
        .asMap()
        .entries
        .where((entry) => (entry.value.title?.isNotEmpty ?? false))
        .toList();

    if (validSubtitles.isEmpty) {
      return const Center(
        child: Text(
          'No subtitles available',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    final currentSubtitleTrack = player.state.track.subtitle;
    int? currentlyPlayingIndex;

    if (currentSubtitleTrack.id.isNotEmpty) {
      currentlyPlayingIndex = player.state.tracks.subtitle.indexWhere(
        (track) => track.id == currentSubtitleTrack.id,
      );
      if (currentlyPlayingIndex == -1) {
        currentlyPlayingIndex = null;
      }
    }

    if (currentlyPlayingIndex == null &&
        currentSubtitleTrack.title?.isNotEmpty == true) {
      currentlyPlayingIndex = player.state.tracks.subtitle.indexWhere(
        (track) =>
            track.title == currentSubtitleTrack.title &&
            track.language == currentSubtitleTrack.language,
      );
      if (currentlyPlayingIndex == -1) {
        currentlyPlayingIndex = null;
      }
    }

    final filterKeys = validSubtitles.map((e) => e.key).toList();

    final resolvedIndex =
        (currentlyPlayingIndex != null &&
            filterKeys.contains(currentlyPlayingIndex))
        ? currentlyPlayingIndex
        : validSubtitles.first.key;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: validSubtitles.length,
      itemBuilder: (context, index) {
        final entry = validSubtitles[index];
        final originalIndex = entry.key;
        final subtitle = entry.value;
        final title = subtitle.title ?? 'Subtitle ${index + 1}';
        final isCurrentlyPlaying = originalIndex == resolvedIndex;

        return _SubtitleOption(
          title: title,
          isSelected: originalIndex == resolvedIndex,
          isCurrentlyPlaying: isCurrentlyPlaying,
          onTap: () {
            onSubtitleChanged(originalIndex);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _SubtitleOption extends StatelessWidget {
  const _SubtitleOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.isCurrentlyPlaying = false,
  });

  final String title;
  final bool isSelected;
  final bool isCurrentlyPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.black,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            if (isCurrentlyPlaying)
              const Icon(Icons.play_circle, color: AppColors.primary, size: 20)
            else if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
            else
              const Icon(
                Icons.circle_outlined,
                color: Colors.white30,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AudioTracksTab extends StatelessWidget {
  const _AudioTracksTab({
    required this.player,
    this.selectedIndex,
    required this.onAudioChanged,
  });

  final Player player;
  final int? selectedIndex;
  final Function(int) onAudioChanged;

  @override
  Widget build(BuildContext context) {
    final audioTracks = player.state.tracks.audio;

    if (audioTracks.isEmpty) {
      return const Center(
        child: Text(
          'No audio tracks available',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    final validAudioTracks = audioTracks
        .asMap()
        .entries
        .where(
          (entry) =>
              (entry.value.title?.isNotEmpty ?? false) ||
              (entry.value.language?.isNotEmpty ?? false),
        )
        .toList();

    if (validAudioTracks.isEmpty) {
      return const Center(
        child: Text(
          'No audio tracks available',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    final currentAudioTrack = player.state.track.audio;
    int? currentlyPlayingIndex;

    if (currentAudioTrack.id.isNotEmpty) {
      currentlyPlayingIndex = player.state.tracks.audio.indexWhere(
        (track) => track.id == currentAudioTrack.id,
      );
      if (currentlyPlayingIndex == -1) {
        currentlyPlayingIndex = null;
      }
    }

    if (currentlyPlayingIndex == null &&
        (currentAudioTrack.title?.isNotEmpty == true ||
            currentAudioTrack.language?.isNotEmpty == true)) {
      currentlyPlayingIndex = player.state.tracks.audio.indexWhere(
        (track) =>
            track.title == currentAudioTrack.title &&
            track.language == currentAudioTrack.language,
      );
      if (currentlyPlayingIndex == -1) {
        currentlyPlayingIndex = null;
      }
    }

    final filterAudioKeys = validAudioTracks.map((e) => e.key).toList();

    final resolvedAudioIndex =
        (currentlyPlayingIndex != null &&
            filterAudioKeys.contains(currentlyPlayingIndex))
        ? currentlyPlayingIndex
        : validAudioTracks.first.key;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: validAudioTracks.length,
      itemBuilder: (context, index) {
        final entry = validAudioTracks[index];
        final originalIndex = entry.key;
        final audio = entry.value;
        final title =
            audio.title ?? audio.language ?? 'Audio Track ${index + 1}';
        final isCurrentlyPlaying = originalIndex == resolvedAudioIndex;

        return _AudioOption(
          title: title,
          isSelected: originalIndex == resolvedAudioIndex,
          isCurrentlyPlaying: isCurrentlyPlaying,
          onTap: () {
            onAudioChanged(originalIndex);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _AudioOption extends StatelessWidget {
  const _AudioOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.isCurrentlyPlaying = false,
  });

  final String title;
  final bool isSelected;
  final bool isCurrentlyPlaying;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.black,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            if (isCurrentlyPlaying)
              const Icon(Icons.play_circle, color: AppColors.primary, size: 20)
            else if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
            else
              const Icon(
                Icons.circle_outlined,
                color: Colors.white30,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
