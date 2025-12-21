import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../app/theme/app_colors.dart';
import '../../../state/content/content_details_provider.dart';
import '../../home/data/home_models.dart';
import '../data/content_details_models.dart';
import 'widgets/video_player_widget.dart';

class ContentDetailsScreen extends ConsumerStatefulWidget {
  const ContentDetailsScreen({required this.contentItem, super.key});

  static const path = '/content-details';

  final ContentItem contentItem;

  @override
  ConsumerState<ContentDetailsScreen> createState() =>
      _ContentDetailsScreenState();
}

class _ContentDetailsScreenState extends ConsumerState<ContentDetailsScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String? _currentVideoUrl;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(
      contentDetailsProvider((
        contentId: widget.contentItem.id,
        serverName: widget.contentItem.serverName,
        serverType: widget.contentItem.serverType,
        initialData: null,
      )),
    );

    return Scaffold(
      backgroundColor: AppColors.black,
      body: detailsAsync.when(
        data: (details) => _buildContent(details),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppColors.danger,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load content',
                style: TextStyle(color: AppColors.textMid, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textLow, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ContentDetails details) {
    final videoUrl = _currentVideoUrl ?? details.videoUrl;

    if (details.isSeries && details.seasons != null) {
      _tabController ??= TabController(
        length: details.seasons!.length,
        vsync: this,
      );
    }

    return Column(
      children: [
        if (videoUrl != null && videoUrl.isNotEmpty)
          VideoPlayerWidget(
            key: ValueKey(videoUrl),
            videoUrl: videoUrl,
            autoPlay: true,
          )
        else
          Container(
            width: double.infinity,
            height: 250,
            color: AppColors.black,
            child: details.posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: details.posterUrl,
                    fit: BoxFit.cover,
                  )
                : const Center(
                    child: Icon(
                      Icons.movie,
                      size: 64,
                      color: AppColors.textLow,
                    ),
                  ),
          ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              details.title,
                              style: const TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textMid,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (details.year != null) ...[
                            Text(
                              details.year!,
                              style: const TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (details.quality != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                details.quality!,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (details.watchTime != null) ...[
                            const Text(
                              '•',
                              style: TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              details.watchTime!,
                              style: const TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          if (details.rating != null) ...[
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star,
                              color: AppColors.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              details.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (details.description != null &&
                          details.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          details.description!,
                          style: const TextStyle(
                            color: AppColors.textMid,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (details.tags != null && details.tags!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: details.tags!
                              .split(',')
                              .where((tag) => tag.trim().isNotEmpty)
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    tag.trim(),
                                    style: const TextStyle(
                                      color: AppColors.textLow,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (details.isSeries && details.seasons != null) ...[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SeasonTabBarDelegate(
                    tabController: _tabController!,
                    seasons: details.seasons!,
                  ),
                ),
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: details.seasons!
                        .map((season) => _buildEpisodeList(season))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeList(Season season) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: season.episodes.length,
      itemBuilder: (context, index) {
        final episode = season.episodes[index];
        final isPlaying = _currentVideoUrl == episode.link;
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
                setState(() {
                  _currentVideoUrl = episode.link;
                });
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

class _SeasonTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SeasonTabBarDelegate({required this.tabController, required this.seasons});

  final TabController tabController;
  final List<Season> seasons;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.black,
        border: Border(
          bottom: BorderSide(color: AppColors.outline, width: 0.5),
        ),
      ),
      child: TabBar(
        controller: tabController,
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tabs: seasons
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
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
