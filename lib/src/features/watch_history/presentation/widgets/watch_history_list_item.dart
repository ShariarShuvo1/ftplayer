import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/watch_history_models.dart';

class WatchHistoryListItem extends StatelessWidget {
  const WatchHistoryListItem({
    required this.watchHistory,
    required this.onDelete,
    required this.onTap,
    this.episodeInfo,
    super.key,
  });

  final WatchHistory watchHistory;
  final VoidCallback onDelete;
  final VoidCallback onTap;
  final Map<String, dynamic>? episodeInfo;

  bool get _isSeries =>
      watchHistory.contentType.contains('series') ||
      watchHistory.contentType.contains('show');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
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
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.surfaceAlt),
            ),
            padding: const EdgeInsets.all(12),
            child: episodeInfo != null && _isSeries
                ? _buildEpisodeItem(context)
                : (_isSeries
                      ? _buildSeriesItem(context)
                      : _buildMovieItem(context)),
          ),
        ),
      ),
    );
  }

  Widget _buildMovieItem(BuildContext context) {
    final progress = watchHistory.progress;
    final percentage = progress?.percentage ?? 0.0;
    final currentTime = progress?.currentTime.toInt() ?? 0;
    final duration = progress?.duration.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Icon(
                  Icons.movie_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    watchHistory.contentTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMid,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (progress != null && duration > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.outline,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage >= 95 ? AppColors.success : AppColors.primary,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDuration(Duration(seconds: currentTime))} / ${_formatDuration(Duration(seconds: duration))}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.textLow),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMid,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEpisodeItem(BuildContext context) {
    if (episodeInfo == null) return const SizedBox.shrink();

    final seasonNumber = episodeInfo!['seasonNumber'] as int?;
    final episodeNumber = episodeInfo!['episodeNumber'] as int?;
    final episodeTitle = episodeInfo!['episodeTitle'] as String?;
    final progress = episodeInfo!['progress'] as ProgressInfo?;
    final percentage = progress?.percentage ?? 0.0;
    final currentTime = progress?.currentTime.toInt() ?? 0;
    final duration = progress?.duration.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Icon(
                  Icons.tv_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    watchHistory.contentTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textHigh,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'S${seasonNumber ?? 0}E${episodeNumber ?? 0}${episodeTitle != null ? ' • $episodeTitle' : ''}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMid),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    watchHistory.serverType.toUpperCase(),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.textLow),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (progress != null && duration > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.outline,
              valueColor: AlwaysStoppedAnimation<Color>(
                percentage >= 95 ? AppColors.success : AppColors.primary,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDuration(Duration(seconds: currentTime))} / ${_formatDuration(Duration(seconds: duration))}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.textLow),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMid,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildSeriesItem(BuildContext context) {
    final seriesProgress = watchHistory.seriesProgress ?? [];
    final totalSeasons = seriesProgress.length;
    final totalEpisodes = seriesProgress.fold<int>(
      0,
      (sum, s) => sum + s.episodes.length,
    );

    // Calculate overall progress for series
    double totalCurrentTime = 0;
    double totalDuration = 0;
    for (final season in seriesProgress) {
      for (final episode in season.episodes) {
        totalCurrentTime += episode.progress.currentTime;
        totalDuration += episode.progress.duration;
      }
    }
    final overallPercentage = totalDuration > 0
        ? (totalCurrentTime / totalDuration) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Center(
                child: Icon(
                  Icons.theater_comedy_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    watchHistory.contentTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMid,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (totalSeasons > 0) ...[
          const SizedBox(height: 8),
          Text(
            '$totalSeasons season${totalSeasons != 1 ? 's' : ''} • $totalEpisodes episode${totalEpisodes != 1 ? 's' : ''}',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.textLow),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (overallPercentage / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.outline,
              valueColor: AlwaysStoppedAnimation<Color>(
                overallPercentage >= 95 ? AppColors.success : AppColors.primary,
              ),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_formatDuration(Duration(seconds: totalCurrentTime.toInt()))} / ${_formatDuration(Duration(seconds: totalDuration.toInt()))}',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.textLow),
              ),
              Text(
                '${overallPercentage.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textMid,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m ${seconds}s';
  }
}
