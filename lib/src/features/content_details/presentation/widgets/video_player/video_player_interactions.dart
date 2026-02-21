part of 'video_player_widget.dart';

mixin _VideoPlayerInteractionMixin on _VideoPlayerBaseState {
  void _togglePlayPause() {
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled &&
        vibrationSettings.vibrateOnVideoController) {
      VibrationHelper.vibrate(vibrationSettings.strength);
    }
    if (_isPlaying) {
      _player.pause();
      WakelockPlus.disable();
      if (widget.onRequestImmediateSave != null) {
        widget.onRequestImmediateSave!();
      }
      _notifyProgressUpdate();
    } else {
      _player.play();
      WakelockPlus.enable();
    }
  }

  void _seekBy(Duration offset) {
    final currentPosition = _player.state.position;
    final target = currentPosition + offset;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration ? _duration : target);

    final currentBufferDuration = _player.state.buffer;
    final bufferedEnd = currentPosition + currentBufferDuration;
    final isTargetBuffered =
        clamped <= bufferedEnd && currentBufferDuration.inSeconds > 0;

    if (!isTargetBuffered) {
      setState(() {
        _isSeeking = true;
      });
    }

    _player.seek(clamped).then((_) {
      if (mounted) {
        setState(() {
          _isSeeking = false;
        });
      }
    });
    _positionNotifier.value = clamped;
  }

  void _showSkipOverlay({required bool forward}) {
    final settings = ref.read(videoPlaybackSettingsProvider);
    final skipSeconds = forward
        ? settings.rightDoubleTapSkipSeconds
        : settings.leftDoubleTapSkipSeconds;

    if (forward) {
      _forwardIndicatorTimer?.cancel();
      setState(() {
        _cumulativeSkipSeconds += skipSeconds;
        _showForwardIndicator = true;
        _showReplayIndicator = false;
      });
      _forwardIndicatorTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() {
            _showForwardIndicator = false;
          });
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) {
              setState(() {
                _cumulativeSkipSeconds = 0;
              });
            }
          });
        }
      });
    } else {
      _replayIndicatorTimer?.cancel();
      setState(() {
        _cumulativeSkipSeconds -= skipSeconds;
        _showReplayIndicator = true;
        _showForwardIndicator = false;
      });
      _replayIndicatorTimer = Timer(const Duration(milliseconds: 700), () {
        if (mounted) {
          setState(() {
            _showReplayIndicator = false;
          });
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) {
              setState(() {
                _cumulativeSkipSeconds = 0;
              });
            }
          });
        }
      });
    }
  }

  void _handleDoubleTap(TapDownDetails details, BoxConstraints constraints) {
    _singleTapTimer?.cancel();

    final settings = ref.read(videoPlaybackSettingsProvider);
    final width = constraints.maxWidth;
    final dx = details.localPosition.dx;
    final leftBound = width * 0.3;
    final rightBound = width * 0.7;

    if (dx <= leftBound) {
      _seekBy(Duration(seconds: -settings.leftDoubleTapSkipSeconds));
      _showSkipOverlay(forward: false);
      final vibrationSettings = ref.read(vibrationSettingsProvider);
      if (vibrationSettings.enabled && vibrationSettings.vibrateOnDoubleTap) {
        VibrationHelper.vibrate(vibrationSettings.strength);
      }
      return;
    }

    if (dx >= rightBound) {
      _seekBy(Duration(seconds: settings.rightDoubleTapSkipSeconds));
      _showSkipOverlay(forward: true);
      final vibrationSettings = ref.read(vibrationSettingsProvider);
      if (vibrationSettings.enabled && vibrationSettings.vibrateOnDoubleTap) {
        VibrationHelper.vibrate(vibrationSettings.strength);
      }
      return;
    }
  }

  void _handleSingleTap(TapDownDetails details, BoxConstraints constraints) {
    _singleTapTimer?.cancel();

    final height = constraints.maxHeight;
    final dy = details.localPosition.dy;
    const bottomInteractionSafeHeight = 120.0;

    if (_showControls && dy >= height - bottomInteractionSafeHeight) {
      return;
    }

    _toggleControls();

    _singleTapTimer = Timer(const Duration(milliseconds: 250), () {});
  }

  Future<void> _handleLongPressStart() async {
    if (!_isPlaying) return;

    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled &&
        vibrationSettings.vibrateOnHoldFastForward) {
      await VibrationHelper.vibrate(vibrationSettings.strength);
    }

    final holdToSpeedRate = ref
        .read(videoPlaybackSettingsProvider)
        .holdToSpeedRate;

    _speedTagAutoHideTimer?.cancel();
    _speedTagAutoHideTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && _isHoldingForSpeed) {
        setState(() {
          _isHoldingForSpeed = false;
        });
      }
    });

    setState(() {
      _isHoldingForSpeed = true;
    });

    await _player.setRate(holdToSpeedRate);
  }

  Future<void> _handleLongPressEnd() async {
    setState(() {
      _isHoldingForSpeed = false;
    });

    await _player.setRate(_currentPlaybackSpeed);
  }

  Future<void> _toggleFullscreen() async {
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled &&
        vibrationSettings.vibrateOnContentDetailsOthers) {
      await VibrationHelper.vibrate(vibrationSettings.strength);
    }

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

  Future<void> _toggleLandscapeSide() async {
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled &&
        vibrationSettings.vibrateOnContentDetailsOthers) {
      await VibrationHelper.vibrate(vibrationSettings.strength);
    }

    setState(() {
      _isLandscapeLeft = !_isLandscapeLeft;
    });

    await SystemChrome.setPreferredOrientations([
      _isLandscapeLeft
          ? DeviceOrientation.landscapeLeft
          : DeviceOrientation.landscapeRight,
    ]);
  }
}
