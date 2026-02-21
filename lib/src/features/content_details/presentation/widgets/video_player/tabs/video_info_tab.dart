import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../../../app/theme/app_colors.dart';

class VideoInfoTab extends StatelessWidget {
  const VideoInfoTab({required this.player, super.key});

  final Player player;

  String _formatBitrate(int? bitrate) {
    if (bitrate == null || bitrate == 0) return 'N/A';
    if (bitrate >= 1000000) {
      return '${(bitrate / 1000000).toStringAsFixed(2)} Mbps';
    }
    return '${(bitrate / 1000).toStringAsFixed(0)} Kbps';
  }

  String _formatSampleRate(int? sampleRate) {
    if (sampleRate == null || sampleRate == 0) return 'N/A';
    return '${(sampleRate / 1000).toStringAsFixed(1)} kHz';
  }

  @override
  Widget build(BuildContext context) {
    final videoParams = player.state.videoParams;
    final audioParams = player.state.audioParams;
    final videoTrack = player.state.track.video;
    final audioTrack = player.state.track.audio;
    final duration = player.state.duration;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoSection(
            title: 'Video',
            icon: Icons.video_library,
            items: [
              _InfoItem(
                label: 'Resolution',
                value: videoParams.w != null && videoParams.h != null
                    ? '${videoParams.w}x${videoParams.h}'
                    : 'N/A',
              ),
              _InfoItem(
                label: 'FPS',
                value: videoTrack.fps != null
                    ? '${videoTrack.fps?.toStringAsFixed(2)} fps'
                    : 'N/A',
              ),
              _InfoItem(label: 'Codec', value: videoTrack.codec ?? 'N/A'),
              _InfoItem(
                label: 'Bitrate',
                value: _formatBitrate(videoTrack.bitrate),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'Audio',
            icon: Icons.audiotrack,
            items: [
              _InfoItem(label: 'Codec', value: audioTrack.codec ?? 'N/A'),
              _InfoItem(
                label: 'Sample Rate',
                value: _formatSampleRate(audioParams.sampleRate),
              ),
              _InfoItem(
                label: 'Channels',
                value: audioParams.channels ?? 'N/A',
              ),
              _InfoItem(
                label: 'Bitrate',
                value: _formatBitrate(audioTrack.bitrate),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _InfoSection(
            title: 'General',
            icon: Icons.info_outline,
            items: [
              _InfoItem(
                label: 'Duration',
                value: duration.inSeconds > 0
                    ? _formatDuration(duration)
                    : 'N/A',
              ),
              _InfoItem(label: 'Decoder', value: videoTrack.decoder ?? 'N/A'),
            ],
          ),
        ],
      ),
    );
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
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i < items.length - 1)
                  Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.outline.withValues(alpha: 0.3),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMid,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppColors.textHigh,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
