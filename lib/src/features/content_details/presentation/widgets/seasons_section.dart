import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../data/content_details_models.dart';

class SeasonsSection extends StatefulWidget {
  const SeasonsSection({
    required this.details,
    required this.tabController,
    required this.currentVideoUrl,
    required this.onEpisodeTap,
    super.key,
  });

  final ContentDetails details;
  final TabController tabController;
  final String? currentVideoUrl;
  final Function(
    Season season,
    int seasonNumber,
    int episodeNumber,
    Episode episode,
  )
  onEpisodeTap;

  @override
  State<SeasonsSection> createState() => _SeasonsSectionState();
}

class _SeasonsSectionState extends State<SeasonsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    if (_isExpanded) {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
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

  @override
  Widget build(BuildContext context) {
    if (!widget.details.isSeries || widget.details.seasons == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Episodes',
                    style: const TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                    controller: widget.tabController,
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
                    tabs: widget.details.seasons!
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
                    controller: widget.tabController,
                    children: widget.details.seasons!.asMap().entries.map((
                      entry,
                    ) {
                      final seasonIndex = entry.key;
                      final season = entry.value;
                      return _buildEpisodeList(season, seasonIndex + 1);
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
        final isPlaying = widget.currentVideoUrl == episode.link;
        final episodeNumber = index + 1;

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
              onTap: () {
                widget.onEpisodeTap(
                  season,
                  seasonNumber,
                  episodeNumber,
                  episode,
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? AppColors.primary
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
                              color: isPlaying
                                  ? AppColors.primary
                                  : AppColors.textHigh,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isPlaying) ...[
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
                    Icon(
                      isPlaying ? Icons.volume_up : Icons.play_circle_outline,
                      color: isPlaying ? AppColors.primary : AppColors.textLow,
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
}
