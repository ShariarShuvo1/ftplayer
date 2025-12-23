import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
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
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  Timer? _controlsTimer;
  Timer? _progressTimer;
  Duration _lastPosition = Duration.zero;

  Player? get player => _player;
  VideoController? get videoController => _videoController;
  bool get isFullscreen => _isFullscreen;

  @override
  void initState() {
    super.initState();
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
    if (!widget._isFromExisting &&
        oldWidget.videoUrl != widget.videoUrl &&
        widget.videoUrl.isNotEmpty &&
        _isInitialized) {
      _reloadVideo();
    }
  }

  Future<void> _reloadVideo() async {
    try {
      _hasError = false;
      _errorMessage = null;
      _position = Duration.zero;
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
        _position = Duration.zero;
      });

      if (widget.initialPosition != null &&
          widget.initialPosition!.inSeconds > 0) {
        await _player.seek(widget.initialPosition!);
      }

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
          final positionDiff = (position.inSeconds - _lastPosition.inSeconds)
              .abs();
          if (positionDiff > 3) {
            _notifyProgressUpdate();
          }
          setState(() {
            _position = position;
            _lastPosition = position;
          });
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
        _position = _player.state.position;
        _duration = _player.state.duration;
        _isPlaying = _player.state.playing;
      });
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
          setState(() {
            _position = position;
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

        if (widget.initialPosition != null &&
            widget.initialPosition!.inSeconds > 0) {
          await _player.seek(widget.initialPosition!);
        }

        if (widget.autoPlay) {
          await _player.play();
          WakelockPlus.enable();
        }
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

  @override
  void dispose() {
    _cancelControlsTimer();
    _cancelProgressTimer();
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

  void _notifyProgressUpdate() {
    if (widget.onProgressUpdate != null && _duration.inSeconds > 0) {
      widget.onProgressUpdate!(
        _position.inSeconds.toDouble(),
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

    return GestureDetector(
      onTap: _toggleControls,
      child: Container(
        width: double.infinity,
        height: _isFullscreen ? MediaQuery.of(context).size.height : 250,
        color: AppColors.black,
        child: Stack(
          children: [
            Center(
              child: Video(
                controller: _videoController,
                controls: NoVideoControls,
              ),
            ),
            if (_isBuffering)
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
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
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(child: SizedBox()),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.replay_10,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                final newPosition =
                                    _position - const Duration(seconds: 10);
                                _player.seek(
                                  newPosition < Duration.zero
                                      ? Duration.zero
                                      : newPosition,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 32),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 36,
                              ),
                              iconSize: 48,
                              padding: const EdgeInsets.all(12),
                              onPressed: _togglePlayPause,
                            ),
                          ),
                          const SizedBox(width: 32),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.forward_10,
                                color: Colors.white,
                                size: 28,
                              ),
                              onPressed: () {
                                final newPosition =
                                    _position + const Duration(seconds: 10);
                                _player.seek(
                                  newPosition > _duration
                                      ? _duration
                                      : newPosition,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          children: [
                            Text(
                              _formatDuration(_position),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
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
                                      ? _position.inMilliseconds
                                            .toDouble()
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
                                  onChanged: (value) {
                                    _player.seek(
                                      Duration(milliseconds: value.toInt()),
                                    );
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
                                color: Colors.white,
                                size: 22,
                              ),
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                              onPressed: _toggleFullscreen,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
