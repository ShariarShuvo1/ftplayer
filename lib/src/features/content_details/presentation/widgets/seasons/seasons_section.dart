import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/utils/vibration_helper.dart';
import '../../../../../state/settings/vibration_settings_provider.dart';
import '../../../../../state/settings/video_playback_settings_provider.dart';
import '../../../data/content_details_models.dart';
import '../../../../watch_history/data/watch_history_models.dart';

class SeasonsSection extends ConsumerStatefulWidget {
  const SeasonsSection({
    required this.seasons,
    required this.currentSeasonNumber,
    required this.currentEpisodeNumber,
    required this.onEpisodeTap,
    this.tabController,
    this.currentVideoUrl,
    this.currentEpisodeId,
    this.onEpisodeDownload,
    this.isEpisodeAvailable,
    this.seriesProgress,
    this.progressUpdateCounter = 0,
    this.enablePeriodicRebuild = false,
    this.useSeasonNameForNumber = false,
    super.key,
  });

  final List<Season> seasons;
  final TabController? tabController;
  final String? currentVideoUrl;
  final String? currentEpisodeId;
  final int? currentSeasonNumber;
  final int? currentEpisodeNumber;
  final Function(
    Season season,
    int seasonNumber,
    int episodeNumber,
    Episode episode,
  )
  onEpisodeTap;
  final Widget Function(
    Season season,
    int seasonNumber,
    int episodeNumber,
    Episode episode,
  )?
  onEpisodeDownload;
  final bool Function(int seasonNumber, int episodeNumber)? isEpisodeAvailable;
  final List<SeasonProgress>? seriesProgress;
  final int progressUpdateCounter;
  final bool enablePeriodicRebuild;
  final bool useSeasonNameForNumber;

  @override
  ConsumerState<SeasonsSection> createState() => _SeasonsSectionState();
}

class _SeasonsSectionState extends ConsumerState<SeasonsSection>
    with SingleTickerProviderStateMixin {
  Timer? _rebuildTimer;
  TabController? _internalTabController;

  TabController get _effectiveTabController =>
      widget.tabController ?? _internalTabController!;

  @override
  void initState() {
    super.initState();
    _initTabController();
    if (widget.enablePeriodicRebuild) {
      _rebuildTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
    _effectiveTabController.addListener(() async {
      if (!_effectiveTabController.indexIsChanging) {
        final vibrationSettings = ref.read(vibrationSettingsProvider);
        if (vibrationSettings.enabled && vibrationSettings.vibrateOnTabChange) {
          await VibrationHelper.vibrate(vibrationSettings.strength);
        }
      }
    });
  }

  void _initTabController() {
    if (widget.tabController == null) {
      int initialTabIndex = 0;
      if (widget.currentSeasonNumber != null && widget.seasons.isNotEmpty) {
        final seasonIndex = widget.seasons.indexWhere((season) {
          final seasonNum = widget.useSeasonNameForNumber
              ? _extractSeasonNumber(season.seasonName)
              : widget.seasons.indexOf(season) + 1;
          return seasonNum == widget.currentSeasonNumber;
        });
        if (seasonIndex >= 0) {
          initialTabIndex = seasonIndex;
        }
      }
      _internalTabController = TabController(
        length: widget.seasons.length,
        vsync: this,
        initialIndex: initialTabIndex,
      );
    }
  }

  @override
  void didUpdateWidget(SeasonsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progressUpdateCounter != widget.progressUpdateCounter ||
        oldWidget.seriesProgress != widget.seriesProgress) {
      setState(() {});
    }
    if (oldWidget.seasons.length != widget.seasons.length &&
        widget.tabController == null) {
      _internalTabController?.dispose();
      _initTabController();
    }
  }

  @override
  void dispose() {
    _rebuildTimer?.cancel();
    _internalTabController?.dispose();
    super.dispose();
  }

  int _getSeasonNumber(int index) {
    if (widget.useSeasonNameForNumber) {
      return _extractSeasonNumber(widget.seasons[index].seasonName);
    }
    return index + 1;
  }

  int _extractSeasonNumber(String seasonName) {
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(seasonName);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seasons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.outline.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
          ),
          child: Text(
            'Episodes',
            style: const TextStyle(
              color: AppColors.textHigh,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          color: AppColors.black,
          child: Column(
            children: [
              Container(
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.black,
                  border: Border(
                    bottom: BorderSide(color: AppColors.outline, width: 0.5),
                  ),
                ),
                child: TabBar(
                  controller: _effectiveTabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMid,
                  labelStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tabs: widget.seasons
                      .map(
                        (season) => Tab(
                          height: 32,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.center,
                            child: Text(season.seasonName),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              AnimatedBuilder(
                animation: _effectiveTabController,
                builder: (context, child) {
                  return IndexedStack(
                    index: _effectiveTabController.index,
                    children: widget.seasons.asMap().entries.map((entry) {
                      final seasonIndex = entry.key;
                      final season = entry.value;
                      return _buildEpisodeList(
                        season,
                        _getSeasonNumber(seasonIndex),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeList(Season season, int seasonNumber) {
    final threshold = ref
        .watch(videoPlaybackSettingsProvider)
        .autoCompleteThreshold;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(season.episodes.length, (index) {
          return _buildEpisodeItem(season, seasonNumber, index, threshold);
        }),
      ),
    );
  }

  Widget _buildEpisodeItem(
    Season season,
    int seasonNumber,
    int index,
    int threshold,
  ) {
    final episode = season.episodes[index];
    final episodeNumber = index + 1;
    final episodeId = episode.id ?? '${seasonNumber}_$episodeNumber';

    final isAvailable =
        widget.isEpisodeAvailable?.call(seasonNumber, episodeNumber) ?? true;

    final isCurrentBySeasonEpisode =
        widget.currentSeasonNumber == seasonNumber &&
        widget.currentEpisodeNumber == episodeNumber;
    final isCurrentByEpisodeId = widget.currentEpisodeId == episodeId;
    final isCurrentByVideoUrl = widget.currentVideoUrl == episode.link;
    final isPlaying =
        isCurrentBySeasonEpisode || isCurrentByEpisodeId || isCurrentByVideoUrl;

    EpisodeProgress? episodeProgress;
    if (widget.seriesProgress != null) {
      final foundSeason = widget.seriesProgress!
          .where((s) => s.seasonNumber == seasonNumber)
          .firstOrNull;
      if (foundSeason != null) {
        episodeProgress = foundSeason.episodes
            .where((e) => e.episodeNumber == episodeNumber)
            .firstOrNull;
      }
    }

    final progressPercentage = episodeProgress?.progress.percentage ?? 0.0;
    final isEpisodeComplete = progressPercentage >= threshold;
    final hasProgress = progressPercentage > 0.0;
    final showCompleted = isEpisodeComplete && isAvailable;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isPlaying
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPlaying
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isAvailable
              ? () async {
                  final vibrationSettings = ref.read(vibrationSettingsProvider);
                  if (vibrationSettings.enabled &&
                      vibrationSettings.vibrateOnSeasonSection) {
                    await VibrationHelper.vibrate(vibrationSettings.strength);
                  }
                  widget.onEpisodeTap(
                    season,
                    seasonNumber,
                    episodeNumber,
                    episode,
                  );
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? AppColors.primary
                            : showCompleted
                            ? AppColors.success
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: isPlaying
                            ? const Icon(
                                Icons.pause,
                                color: AppColors.black,
                                size: 24,
                              )
                            : showCompleted
                            ? const Icon(
                                Icons.check,
                                color: AppColors.black,
                                size: 24,
                              )
                            : Text(
                                episodeNumber.toString(),
                                style: const TextStyle(
                                  color: AppColors.textMid,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            episode.title,
                            style: TextStyle(
                              color: isAvailable
                                  ? (isPlaying
                                        ? AppColors.primary
                                        : AppColors.textHigh)
                                  : AppColors.textLow,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isPlaying) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.play_circle_filled,
                                  size: 14,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Now Playing',
                                  style: TextStyle(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (showCompleted) ...[
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 14,
                                  color: AppColors.success.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Completed',
                                  style: TextStyle(
                                    color: AppColors.success.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ] else if (hasProgress &&
                              !isEpisodeComplete &&
                              isAvailable) ...[
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (progressPercentage / 100).clamp(
                                  0.0,
                                  1.0,
                                ),
                                backgroundColor: AppColors.outline,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                                minHeight: 3,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 2),
                    if (widget.onEpisodeDownload != null) ...[
                      widget.onEpisodeDownload!(
                        season,
                        seasonNumber,
                        episodeNumber,
                        episode,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
