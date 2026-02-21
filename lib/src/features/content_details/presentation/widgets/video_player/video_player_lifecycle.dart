part of 'video_player_widget.dart';

mixin _VideoPlayerLifecycleMixin on _VideoPlayerBaseState {
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
      _hasTriggeredAutoAdvance = false;
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
        extras: {
          'cache': 'yes',
          'cache-secs': '300',
          'demuxer-max-bytes': '800000000',
          'demuxer-readahead-secs': '180',
          'stream-buffer-size': '20971520',
          'network-timeout': '120',
          'demuxer-seekable-cache': 'yes',
          'cache-pause-initial': 'yes',
          'cache-pause-wait': '3',
          'prefetch-playlist': 'yes',
          'force-seekable': 'yes',
          'rtsp-transport': 'tcp',
          'icy-metadata': 'no',
          'audio-lavc-framedrop': 'yes',
          'audio-normalize': 'no',
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
    } catch (e, stackTrace) {
      _logger.e(
        '[_reloadVideo] Error reloading video: $e',
        error: e,
        stackTrace: stackTrace,
      );
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
        _logger.e('[_setupExistingPlayer] Player error event: $error');
        _logger.e('[_setupExistingPlayer] Player state: ${_player.state}');

        if (error.toLowerCase().contains('could not open codec')) {
          _logger.w(
            '[_setupExistingPlayer] Codec error detected, but may be non-fatal. Checking playback state...',
          );

          Future.delayed(const Duration(milliseconds: 500), () {
            if (_player.state.duration > Duration.zero) {
              return;
            }

            if (!_player.state.playing &&
                _player.state.duration == Duration.zero) {
              _logger.e(
                '[_setupExistingPlayer] Codec error is fatal - no duration and not playing',
              );
              if (mounted && !_isDisposing) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error;
                });
              }
            }
          });
          return;
        }

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

          _checkAndTriggerAutoAdvance(position);
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
    } catch (e, stackTrace) {
      _logger.e(
        '[_setupExistingPlayer] Error setting up player: $e',
        error: e,
        stackTrace: stackTrace,
      );
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
      _player = Player(
        configuration: const PlayerConfiguration(title: 'FTPlayer'),
      );
      _videoController = VideoController(_player);

      _player.stream.error.listen((error) {
        _logger.e('[_initializePlayer] Player error event: $error');
        _logger.e('[_initializePlayer] Player state: ${_player.state}');
        _logger.e(
          '[_initializePlayer] Current media: ${_player.state.playlist}',
        );

        if (error.toLowerCase().contains('could not open codec')) {
          _logger.w(
            '[_initializePlayer] Codec error detected, but may be non-fatal. Checking playback state...',
          );

          Future.delayed(const Duration(milliseconds: 500), () {
            if (_player.state.duration > Duration.zero) {
              _logger.i(
                '[_initializePlayer] Duration available despite codec error - playback recovered. Ignoring error.',
              );
              return;
            }

            if (!_player.state.playing &&
                _player.state.duration == Duration.zero) {
              _logger.e(
                '[_initializePlayer] Codec error is fatal - no duration and not playing',
              );
              if (mounted && !_isDisposing) {
                setState(() {
                  _hasError = true;
                  _errorMessage = error;
                });
              }
            }
          });
          return;
        }

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

          _checkAndTriggerAutoAdvance(position);
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

      final media = Media(
        widget.videoUrl,
        httpHeaders: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 11; Mobile)',
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip, deflate',
        },
        extras: {
          'cache': 'yes',
          'cache-secs': '300',
          'demuxer-max-bytes': '800000000',
          'demuxer-readahead-secs': '180',
          'stream-buffer-size': '20971520',
          'network-timeout': '120',
          'demuxer-seekable-cache': 'yes',
          'cache-pause-initial': 'yes',
          'cache-pause-wait': '3',
          'prefetch-playlist': 'yes',
          'force-seekable': 'yes',
          'rtsp-transport': 'tcp',
          'icy-metadata': 'no',
          'audio-lavc-framedrop': 'yes',
          'audio-normalize': 'no',
        },
      );

      await _player.open(media, play: false);

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
    } catch (e, stackTrace) {
      _logger.e(
        '[_initializePlayer] Error initializing player: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _logger.e('[_initializePlayer] Stack trace: $stackTrace');
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
      _logger.d(
        '[_waitForPlayerReadyAndSeek] Already applied initial seek, skipping',
      );
      return;
    }

    if (widget.initialPosition == null ||
        widget.initialPosition!.inSeconds < 0) {
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
        widget.initialPosition!.inSeconds < 0) {
      return;
    }

    try {
      _hasAppliedInitialSeek = true;
      final seekPosition = widget.initialPosition!;
      await _player.seek(seekPosition);
      _positionNotifier.value = seekPosition;
      _lastPosition = seekPosition;
    } catch (e, stackTrace) {
      _logger.e(
        '[_applyInitialSeek] Error applying initial seek: $e',
        error: e,
        stackTrace: stackTrace,
      );
      _hasAppliedInitialSeek = false;
    }
  }

  Future<void> _loadSubtitleSettings() async {
    final loaded = ref.read(subtitleSettingsProvider);
    if (mounted) {
      setState(() {
        _subtitleSettings = loaded;
      });
    }
  }

  void _checkAndTriggerAutoAdvance(Duration position) {
    if (_hasTriggeredAutoAdvance ||
        !widget.canGoToNextEpisode ||
        widget.onNextEpisode == null ||
        _duration.inSeconds <= 0) {
      return;
    }

    final progressPercentage = (position.inSeconds / _duration.inSeconds) * 100;

    if (progressPercentage >= 99.5 && !_isBuffering) {
      _hasTriggeredAutoAdvance = true;

      if (widget.onProgressUpdate != null) {
        final durationSeconds = _duration.inSeconds.toDouble();
        widget.onProgressUpdate!(durationSeconds, durationSeconds);
      }

      if (widget.onRequestImmediateSave != null) {
        widget.onRequestImmediateSave!();
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && widget.onNextEpisode != null) {
          widget.onNextEpisode!();
        }
      });
    }
  }

  @override
  void dispose() {
    _initializationCheckTimer?.cancel();
    _singleTapTimer?.cancel();
    _speedTagAutoHideTimer?.cancel();
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
        _logger.e('[dispose] Error disposing player: $e', error: e);
      }
      WakelockPlus.disable();
    }
    _positionNotifier.dispose();
    super.dispose();
  }

  void transferOwnership() {
    _ownershipTransferred = true;
  }
}
