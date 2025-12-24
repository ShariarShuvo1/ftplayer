import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../state/downloads/download_provider.dart';
import '../../../downloads/data/download_models.dart';

class DownloadButton extends ConsumerWidget {
  const DownloadButton({
    required this.contentId,
    required this.title,
    required this.posterUrl,
    required this.description,
    required this.serverName,
    required this.serverType,
    required this.ftpServerId,
    required this.contentType,
    required this.videoUrl,
    this.year,
    this.quality,
    this.rating,
    this.seasonNumber,
    this.episodeNumber,
    this.episodeTitle,
    this.seriesTitle,
    this.totalSeasons,
    this.metadata,
    this.isCompact = false,
    super.key,
  });

  final String contentId;
  final String title;
  final String posterUrl;
  final String description;
  final String serverName;
  final String serverType;
  final String ftpServerId;
  final String contentType;
  final String videoUrl;
  final String? year;
  final String? quality;
  final double? rating;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? episodeTitle;
  final String? seriesTitle;
  final int? totalSeasons;
  final Map<String, dynamic>? metadata;
  final bool isCompact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDownloaded = ref.watch(
      isContentDownloadedProvider((
        contentId: contentId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      )),
    );

    final isDownloading = ref.watch(
      isContentDownloadingProvider((
        contentId: contentId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      )),
    );

    final downloadTask = ref.watch(
      contentDownloadTaskProvider((
        contentId: contentId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      )),
    );

    if (isDownloaded) {
      return _buildDownloadedButton(context);
    }

    if (isDownloading && downloadTask != null) {
      return _buildDownloadingButton(context, ref, downloadTask);
    }

    return _buildDownloadButton(context, ref);
  }

  Widget _buildDownloadedButton(BuildContext context) {
    if (isCompact) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.download_done_rounded,
          color: AppColors.success,
          size: 18,
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: SizedBox(
        height: 48,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.download_done_rounded,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Downloaded',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadingButton(
    BuildContext context,
    WidgetRef ref,
    DownloadTask task,
  ) {
    final isActiveDownload = task.status == DownloadStatus.downloading;
    final isPaused = task.status == DownloadStatus.paused;
    final isFailed = task.status == DownloadStatus.failed;

    if (isCompact) {
      return GestureDetector(
        onTap: () {
          if (isFailed) {
            ref.read(downloadNotifierProvider.notifier).retryDownload(task.id);
          } else if (isPaused) {
            ref.read(downloadNotifierProvider.notifier).resumeDownload(task.id);
          } else if (isActiveDownload) {
            ref.read(downloadNotifierProvider.notifier).pauseDownload(task.id);
          }
        },
        child: SizedBox(
          width: 32,
          height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(32, 32),
                painter: _CircularProgressPainter(
                  progress: task.progress,
                  color: isFailed
                      ? AppColors.danger
                      : (isPaused ? AppColors.warning : AppColors.primary),
                  backgroundColor: AppColors.surfaceAlt,
                  strokeWidth: 2.5,
                ),
              ),
              Icon(
                isFailed
                    ? Icons.refresh_rounded
                    : (isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded),
                color: isFailed
                    ? AppColors.danger
                    : (isPaused ? AppColors.warning : AppColors.primary),
                size: 16,
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (isFailed) {
          ref.read(downloadNotifierProvider.notifier).retryDownload(task.id);
        } else if (isPaused) {
          ref.read(downloadNotifierProvider.notifier).resumeDownload(task.id);
        } else if (isActiveDownload) {
          ref.read(downloadNotifierProvider.notifier).pauseDownload(task.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color:
              (isFailed
                      ? AppColors.danger
                      : (isPaused ? AppColors.warning : AppColors.primary))
                  .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                (isFailed
                        ? AppColors.danger
                        : (isPaused ? AppColors.warning : AppColors.primary))
                    .withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(20, 20),
                        painter: _CircularProgressPainter(
                          progress: task.progress,
                          color: isFailed
                              ? AppColors.danger
                              : (isPaused
                                    ? AppColors.warning
                                    : AppColors.primary),
                          backgroundColor: AppColors.surfaceAlt,
                          strokeWidth: 2.5,
                        ),
                      ),
                      Icon(
                        isFailed
                            ? Icons.refresh_rounded
                            : (isPaused
                                  ? Icons.play_arrow_rounded
                                  : Icons.pause_rounded),
                        color: isFailed
                            ? AppColors.danger
                            : (isPaused
                                  ? AppColors.warning
                                  : AppColors.primary),
                        size: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isFailed ? 'Retry' : (isPaused ? 'Resume' : 'Pause'),
                  style: TextStyle(
                    color: isFailed
                        ? AppColors.danger
                        : (isPaused ? AppColors.warning : AppColors.primary),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(BuildContext context, WidgetRef ref) {
    if (isCompact) {
      return GestureDetector(
        onTap: () => _startDownload(ref),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.download_rounded,
            color: AppColors.primary,
            size: 18,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _startDownload(ref),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.download_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Download',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _startDownload(WidgetRef ref) {
    ref
        .read(downloadNotifierProvider.notifier)
        .addDownload(
          contentId: contentId,
          title: title,
          posterUrl: posterUrl,
          description: description,
          serverName: serverName,
          serverType: serverType,
          ftpServerId: ftpServerId,
          contentType: contentType,
          videoUrl: videoUrl,
          year: year,
          quality: quality,
          rating: rating,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
          episodeTitle: episodeTitle,
          seriesTitle: seriesTitle,
          totalSeasons: totalSeasons,
          metadata: metadata,
        );
  }
}

class _CircularProgressPainter extends CustomPainter {
  _CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
