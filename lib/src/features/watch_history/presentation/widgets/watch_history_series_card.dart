import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/vibration_helper.dart';
import '../../../../state/settings/video_playback_settings_provider.dart';
import '../../../../state/settings/vibration_settings_provider.dart';
import '../../data/watch_history_models.dart';

class WatchHistorySeriesCard extends ConsumerWidget {
  const WatchHistorySeriesCard({
    required this.watchHistory,
    required this.onDelete,
    required this.onTap,
    required this.onEpisodeTap,
    required this.isExpanded,
    required this.onExpansionChanged,
    this.isDownloaded = true,
    this.isOffline = false,
    super.key,
  });

  final WatchHistory watchHistory;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final void Function(int seasonNumber, int episodeNumber, String? episodeId)
  onEpisodeTap;
  final bool isExpanded;
  final VoidCallback onExpansionChanged;
  final bool isDownloaded;
  final bool isOffline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold = ref
        .watch(videoPlaybackSettingsProvider)
        .autoCompleteThreshold;
    final seriesProgress = watchHistory.seriesProgress ?? [];

    int watchedEpisodes = 0;
    final allEpisodes = <Map<String, dynamic>>[];

    for (final season in seriesProgress) {
      for (final episode in season.episodes) {
        if (episode.progress.percentage >= threshold) {
          watchedEpisodes++;
        }
        allEpisodes.add({'season': season, 'episode': episode});
      }
    }

    allEpisodes.sort((a, b) {
      final aEp = a['episode'] as EpisodeProgress;
      final bEp = b['episode'] as EpisodeProgress;
      return bEp.lastWatchedAt.compareTo(aEp.lastWatchedAt);
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        enabled: !isExpanded,
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: 'Delete',
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
        child: Opacity(
          opacity: (isOffline && !isDownloaded) ? 0.4 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isOffline && !isDownloaded)
                    ? AppColors.textLow.withValues(alpha: 0.3)
                    : AppColors.surfaceAlt,
              ),
            ),
            child: Column(
              children: [
                GestureDetector(
                  onTap: (isOffline && !isDownloaded) ? null : onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: _buildPosterImage(
                            watchHistory.metadata?['posterUrl'],
                            Icons.tv_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                watchHistory.contentTitle,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textHigh,
                                    ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.storage_outlined,
                                    size: 12,
                                    color: AppColors.textMid,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    watchHistory.serverType.toUpperCase(),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: AppColors.textMid),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final vibrationSettings = ref.read(
                                    vibrationSettingsProvider,
                                  );
                                  if (vibrationSettings.enabled) {
                                    await VibrationHelper.vibrate(
                                      vibrationSettings.strength,
                                    );
                                  }
                                  onExpansionChanged();
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.play_circle_outline,
                                      size: 14,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$watchedEpisodes episode${watchedEpisodes != 1 ? 's' : ''} watched',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(width: 4),
                                    AnimatedRotation(
                                      turns: isExpanded ? 0.5 : 0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right,
                          color: AppColors.textLow,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                if (isExpanded)
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.outline, width: 0.5),
                      ),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: allEpisodes.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 0.5,
                        color: AppColors.outline.withValues(alpha: 0.3),
                      ),
                      itemBuilder: (context, index) {
                        final item = allEpisodes[index];
                        final season = item['season'] as SeasonProgress;
                        final episode = item['episode'] as EpisodeProgress;
                        final percentage = episode.progress.percentage;
                        final isWatched = percentage >= threshold;

                        return InkWell(
                          onTap: () {
                            onEpisodeTap(
                              season.seasonNumber,
                              episode.episodeNumber,
                              episode.episodeId,
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isWatched
                                        ? AppColors.success.withValues(
                                            alpha: 0.15,
                                          )
                                        : AppColors.primary.withValues(
                                            alpha: 0.15,
                                          ),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: isWatched
                                          ? AppColors.success
                                          : AppColors.primary,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    'S${season.seasonNumber}E${episode.episodeNumber}',
                                    style: TextStyle(
                                      color: isWatched
                                          ? AppColors.success
                                          : AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (episode.episodeTitle != null &&
                                          episode.episodeTitle!.isNotEmpty)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                episode.episodeTitle!,
                                                style: TextStyle(
                                                  color: AppColors.textHigh,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                              child: LinearProgressIndicator(
                                                value: (percentage / 100).clamp(
                                                  0.0,
                                                  1.0,
                                                ),
                                                backgroundColor:
                                                    AppColors.outline,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      isWatched
                                                          ? AppColors.success
                                                          : AppColors.primary,
                                                    ),
                                                minHeight: 3,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${percentage.toStringAsFixed(0)}%',
                                            style: TextStyle(
                                              color: AppColors.textLow,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterImage(String? posterUrl, IconData fallbackIcon) {
    const posterWidth = 60.0;
    const posterHeight = 90.0;

    if (posterUrl == null || posterUrl.isEmpty) {
      return Container(
        width: posterWidth,
        height: posterHeight,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Icon(fallbackIcon, color: AppColors.primary, size: 32),
        ),
      );
    }

    final isLocalFile =
        posterUrl.startsWith('/') ||
        posterUrl.contains(':\\') ||
        posterUrl.startsWith('file://');

    if (isLocalFile) {
      final filePath = posterUrl.replaceFirst('file://', '');
      final file = File(filePath);

      if (file.existsSync()) {
        return Image.file(
          file,
          width: posterWidth,
          height: posterHeight,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: posterWidth,
            height: posterHeight,
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Icon(fallbackIcon, color: AppColors.primary, size: 32),
            ),
          ),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: posterUrl,
      width: posterWidth,
      height: posterHeight,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: posterWidth,
        height: posterHeight,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        width: posterWidth,
        height: posterHeight,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Icon(fallbackIcon, color: AppColors.primary, size: 32),
        ),
      ),
    );
  }
}
