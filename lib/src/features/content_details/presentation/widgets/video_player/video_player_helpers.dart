part of 'video_player_widget.dart';

mixin _VideoPlayerHelpersMixin on _VideoPlayerBaseState {
  double _getPullUpProgress() {
    return (_pullUpOffset / _fullscreenTriggerThreshold).clamp(0.0, 1.0);
  }

  double _getPullDownProgress() {
    return (_pullDownOffset / _fullscreenExitThreshold).clamp(0.0, 1.0);
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
      builder: (context) => MediaMenuBottomSheet(
        player: _player,
        selectedSubtitleIndex: currentSubtitleIndex ?? _selectedSubtitleIndex,
        selectedAudioIndex: currentAudioIndex ?? _selectedAudioIndex,
        currentSpeed: _currentPlaybackSpeed,
        subtitleSettings: _subtitleSettings,
        isFullscreen: _isFullscreen,
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
        onSpeedChanged: (speed) {
          setState(() {
            _currentPlaybackSpeed = speed;
          });
          _player.setRate(speed);
        },
        onSubtitleSettingsChanged: _updateSubtitleSettings,
      ),
    );
  }
}
