import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../../../app/theme/app_colors.dart';
import '../../../../../../core/utils/vibration_helper.dart';
import '../../../../../../state/settings/vibration_settings_provider.dart';

class AudioTracksTab extends StatefulWidget {
  const AudioTracksTab({
    required this.player,
    this.selectedIndex,
    required this.onAudioChanged,
    super.key,
  });

  final Player player;
  final int? selectedIndex;
  final Function(int) onAudioChanged;

  @override
  State<AudioTracksTab> createState() => _AudioTracksTabState();
}

class _AudioTracksTabState extends State<AudioTracksTab> {
  StreamSubscription? _trackSubscription;

  @override
  void initState() {
    super.initState();
    _trackSubscription = widget.player.stream.track.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _trackSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioTracks = widget.player.state.tracks.audio;

    if (audioTracks.isEmpty) {
      return const Center(
        child: Text(
          'No audio tracks available',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    final currentAudioTrack = widget.player.state.track.audio;
    int? currentlyPlayingIndex;

    if (currentAudioTrack.id.isNotEmpty) {
      currentlyPlayingIndex = widget.player.state.tracks.audio.indexWhere(
        (track) => track.id == currentAudioTrack.id,
      );
      if (currentlyPlayingIndex == -1) {
        currentlyPlayingIndex = null;
      }
    }

    if (currentlyPlayingIndex == null &&
        (currentAudioTrack.title?.isNotEmpty == true ||
            currentAudioTrack.language?.isNotEmpty == true)) {
      currentlyPlayingIndex = widget.player.state.tracks.audio.indexWhere(
        (track) =>
            track.title == currentAudioTrack.title &&
            track.language == currentAudioTrack.language,
      );
      if (currentlyPlayingIndex == -1) {
        currentlyPlayingIndex = null;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: audioTracks.length,
      itemBuilder: (context, index) {
        final audio = audioTracks[index];
        final title = (audio.title?.isNotEmpty ?? false)
            ? audio.title!
            : (audio.language?.isNotEmpty ?? false)
            ? 'Audio - ${audio.language}'
            : 'Audio Track ${index + 1}';
        final isCurrentlyPlaying = index == currentlyPlayingIndex;

        return _AudioOption(
          title: title,
          isSelected: index == currentlyPlayingIndex,
          isCurrentlyPlaying: isCurrentlyPlaying,
          onTap: () {
            widget.onAudioChanged(index);
          },
        );
      },
    );
  }
}

class _AudioOption extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        final vibrationSettings = ref.read(vibrationSettingsProvider);
        if (vibrationSettings.enabled &&
            vibrationSettings.vibrateOnBottomSheet) {
          VibrationHelper.vibrate(vibrationSettings.strength);
        }
        onTap();
      },
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
