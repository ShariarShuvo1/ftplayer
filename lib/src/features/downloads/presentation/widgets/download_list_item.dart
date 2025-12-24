import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/download_models.dart';
import '../../../../state/downloads/download_provider.dart';

class DownloadListItem extends ConsumerWidget {
  const DownloadListItem({
    required this.download,
    required this.onTap,
    required this.onDelete,
    super.key,
  });

  final DownloadedContent download;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.download_done_rounded,
                    color: AppColors.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (download.isEpisode &&
                          download.seriesTitle != null) ...[
                        Text(
                          download.seriesTitle!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHigh,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          download.displayTitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMid),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        Text(
                          download.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHigh,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            download.serverType.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.textLow),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatFileSize(download.fileSize),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.play_circle_outline,
                  color: AppColors.primary,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }
}

class DownloadTaskItem extends ConsumerWidget {
  const DownloadTaskItem({
    required this.task,
    this.disablePauseResume = false,
    super.key,
  });

  final DownloadTask task;
  final bool disablePauseResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final isFailed = task.status == DownloadStatus.failed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDownloading
                ? AppColors.primary.withValues(alpha: 0.5)
                : (isFailed
                      ? AppColors.danger.withValues(alpha: 0.5)
                      : AppColors.surfaceAlt),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDownloading
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : (isFailed
                              ? AppColors.danger.withValues(alpha: 0.2)
                              : (isPaused
                                    ? AppColors.warning.withValues(alpha: 0.2)
                                    : AppColors.textLow.withValues(
                                        alpha: 0.2,
                                      ))),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDownloading
                        ? Icons.downloading_rounded
                        : (isFailed
                              ? Icons.error_outline
                              : (isPaused
                                    ? Icons.pause_rounded
                                    : Icons.hourglass_empty_rounded)),
                    color: isDownloading
                        ? AppColors.primary
                        : (isFailed
                              ? AppColors.danger
                              : (isPaused
                                    ? AppColors.warning
                                    : AppColors.textLow)),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (task.isEpisode && task.seriesTitle != null) ...[
                        Text(
                          task.seriesTitle!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHigh,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          task.displayTitle,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.textMid),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        Text(
                          task.title,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textHigh,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              task.status.label,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: isDownloading
                                        ? AppColors.primary
                                        : (isFailed
                                              ? AppColors.danger
                                              : (isPaused
                                                    ? AppColors.warning
                                                    : AppColors.textLow)),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildActions(context, ref),
              ],
            ),
            if (isDownloading || isPaused) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progress,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDownloading ? AppColors.primary : AppColors.warning,
                  ),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(task.progress * 100).toStringAsFixed(1)}%',
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.textMid),
                  ),
                  if (isDownloading)
                    Flexible(
                      child: Text(
                        '${task.downloadedSizeFormatted} / ${task.totalSizeFormatted}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textMid,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (isDownloading) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.speed, size: 12, color: AppColors.textLow),
                        const SizedBox(width: 4),
                        Text(
                          task.speed != null ? task.speedFormatted : '--',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textLow),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 12,
                          color: AppColors.textLow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          task.eta != null ? task.etaFormatted : '--:--',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.textLow),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ],
            if (isFailed && task.error != null) ...[
              const SizedBox(height: 8),
              Text(
                task.error!,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.danger),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, WidgetRef ref) {
    final isDownloading = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final isQueued = task.status == DownloadStatus.queued;
    final isFailed = task.status == DownloadStatus.failed;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isDownloading && !disablePauseResume)
          IconButton(
            onPressed: () => ref
                .read(downloadNotifierProvider.notifier)
                .pauseDownload(task.id),
            icon: const Icon(Icons.pause_rounded),
            color: AppColors.warning,
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        if ((isPaused || isQueued) && !disablePauseResume)
          IconButton(
            onPressed: () => ref
                .read(downloadNotifierProvider.notifier)
                .resumeDownload(task.id),
            icon: const Icon(Icons.play_arrow_rounded),
            color: AppColors.success,
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        if (isFailed && !disablePauseResume)
          IconButton(
            onPressed: () => ref
                .read(downloadNotifierProvider.notifier)
                .retryDownload(task.id),
            icon: const Icon(Icons.refresh_rounded),
            color: AppColors.primary,
            iconSize: 24,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        IconButton(
          onPressed: () => ref
              .read(downloadNotifierProvider.notifier)
              .cancelDownload(task.id),
          icon: const Icon(Icons.close_rounded),
          color: AppColors.danger,
          iconSize: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }
}
