import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../state/downloads/download_provider.dart';
import '../../../home/data/home_models.dart';
import '../../data/content_details_models.dart';

class OfflineSeasonsSection extends ConsumerStatefulWidget {
  const OfflineSeasonsSection({
    required this.seasons,
    required this.currentSeasonNumber,
    required this.currentEpisodeNumber,
    required this.currentEpisodeId,
    required this.contentItem,
    required this.onEpisodeSelected,
    super.key,
  });

  final List<Season> seasons;
  final int? currentSeasonNumber;
  final int? currentEpisodeNumber;
  final String? currentEpisodeId;
  final ContentItem contentItem;
  final Function(Season season, Episode episode) onEpisodeSelected;

  @override
  ConsumerState<OfflineSeasonsSection> createState() {
    return _OfflineSeasonsSectionState();
  }
}

class _OfflineSeasonsSectionState extends ConsumerState<OfflineSeasonsSection>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late TabController _tabController;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    int initialTabIndex = 0;
    if (widget.currentSeasonNumber != null && widget.seasons.isNotEmpty) {
      final seasonIndex = widget.seasons.indexWhere((season) {
        return _extractSeasonNumber(season.seasonName) ==
            widget.currentSeasonNumber;
      });
      if (seasonIndex >= 0) {
        initialTabIndex = seasonIndex;
      }
    }

    _tabController = TabController(
      length: widget.seasons.length,
      vsync: this,
      initialIndex: initialTabIndex,
    );
    if (_isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  bool _isEpisodeAvailableOffline(int seasonNumber, int episodeNumber) {
    final downloaded = ref.read(
      downloadedContentItemProvider((
        contentId: widget.contentItem.id,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      )),
    );
    return downloaded != null && downloaded.localPath.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _toggleExpanded,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Episodes',
                    style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _animationController.value * 3.14159,
                        child: Icon(
                          Icons.expand_less,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _animationController,
          axisAlignment: -1.0,
          child: Container(
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
                    controller: _tabController,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              alignment: Alignment.center,
                              child: Text(season.seasonName),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                SizedBox(
                  height: 400,
                  child: TabBarView(
                    controller: _tabController,
                    children: widget.seasons.asMap().entries.map((entry) {
                      final season = entry.value;
                      final seasonNumber = _extractSeasonNumber(
                        season.seasonName,
                      );
                      return _buildEpisodeList(season, seasonNumber);
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeList(Season season, int seasonNumber) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: season.episodes.length,
      itemBuilder: (context, index) {
        final episode = season.episodes[index];
        final isAvailable = _isEpisodeAvailableOffline(seasonNumber, index + 1);
        final episodeNumber = index + 1;
        final episodeId = episode.id ?? '${seasonNumber}_$episodeNumber';
        final isCurrentEpisode =
            widget.currentEpisodeId == episodeId ||
            (widget.currentSeasonNumber == seasonNumber &&
                widget.currentEpisodeNumber == episodeNumber);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isCurrentEpisode
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isCurrentEpisode
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
                  ? () {
                      widget.onEpisodeSelected(season, episode);
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isCurrentEpisode
                            ? AppColors.primary
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: isCurrentEpisode
                            ? const Icon(
                                Icons.pause,
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
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            episode.title,
                            style: TextStyle(
                              color: isAvailable
                                  ? (isCurrentEpisode
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
                          if (isCurrentEpisode) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.play_circle_filled,
                                  size: 14,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 4),
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
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (!isAvailable)
                      Icon(
                        Icons.lock,
                        color: AppColors.textLow.withValues(alpha: 0.5),
                        size: 24,
                      )
                    else
                      Icon(
                        isCurrentEpisode
                            ? Icons.volume_up
                            : Icons.play_circle_outline,
                        color: isCurrentEpisode
                            ? AppColors.primary
                            : AppColors.textLow,
                        size: 24,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  int _extractSeasonNumber(String seasonName) {
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(seasonName);
    return match != null ? int.parse(match.group(0)!) : 0;
  }
}
