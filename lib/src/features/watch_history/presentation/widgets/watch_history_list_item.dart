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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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
                  Text(
                    watchHistory.serverType.toUpperCase(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMid),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEpisodeItem(BuildContext context) {
    if (episodeInfo == null) return const SizedBox.shrink();

    final seasonNumber = episodeInfo!['seasonNumber'] as int?;
    final episodeNumber = episodeInfo!['episodeNumber'] as int?;
    final episodeTitle = episodeInfo!['episodeTitle'] as String?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
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
                  Text(
                    watchHistory.serverType.toUpperCase(),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textMid),
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
        ],
      ],
    );
  }
}
