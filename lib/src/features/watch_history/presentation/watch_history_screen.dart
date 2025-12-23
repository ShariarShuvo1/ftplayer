import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/right_drawer.dart';
import '../../../core/widgets/search_overlay.dart';
import '../../../state/watch_history/watch_history_provider.dart';
import '../data/watch_history_models.dart';
import '../../../features/home/data/home_models.dart';
import '../../../features/content_details/presentation/content_details_screen.dart';
import '../../../features/search/presentation/search_result_screen.dart';
import 'widgets/watch_history_list_item.dart';

class WatchHistoryScreen extends ConsumerStatefulWidget {
  const WatchHistoryScreen({super.key});

  static const path = '/watch-history';

  @override
  ConsumerState<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends ConsumerState<WatchHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentPage = 1;
  bool _showSearch = false;
  String _searchText = '';

  final List<WatchStatus> statuses = [
    WatchStatus.watching,
    WatchStatus.completed,
    WatchStatus.onHold,
    WatchStatus.dropped,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: statuses.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentPage = 1;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _showSearch = !_showSearch;
    });
  }

  void _handleSearch(String query) {
    setState(() {
      _showSearch = false;
    });
    context.push(SearchResultScreen.path, extra: query);
  }

  void _handleSearchClose(String query) {
    setState(() {
      _showSearch = false;
      _searchText = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Watch History',
      endDrawer: const RightDrawer(),
      actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: _toggleSearch,
          icon: const Icon(Icons.search),
          color: AppColors.primary,
        ),
        Builder(
          builder: (context) {
            return IconButton(
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu),
              color: AppColors.primary,
            );
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            tabs: statuses
                .map(
                  (status) => Tab(
                    height: 32,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      child: Text(status.label),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      padding: EdgeInsets.zero,
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: statuses.map((status) {
              return _buildWatchHistoryList(status);
            }).toList(),
          ),
          if (_showSearch)
            Positioned.fill(
              child: SearchOverlay(
                onClose: _handleSearchClose,
                onSearch: _handleSearch,
                initialQuery: _searchText,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWatchHistoryList(WatchStatus status) {
    return ref
        .watch(
          watchHistoryListProvider((
            status: status.value,
            limit: 50,
            page: _currentPage,
          )),
        )
        .when(
          data: (response) {
            if (response.watchHistories.isEmpty) {
              return Center(
                child: Text(
                  'No ${status.label.toLowerCase()} items',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.textMid),
                ),
              );
            }

            final expandedItems = _expandEpisodes(response.watchHistories);

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(
                  watchHistoryListProvider((
                    status: status.value,
                    limit: 50,
                    page: _currentPage,
                  )),
                );
              },
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                itemCount: expandedItems.length,
                itemBuilder: (context, index) {
                  final item = expandedItems[index];
                  return WatchHistoryListItem(
                    watchHistory: item['history'] as WatchHistory,
                    episodeInfo: item['episode'] as Map<String, dynamic>?,
                    onDelete: () => _deleteWatchHistory(item['history'].id),
                    onTap: () => _navigateToContent(
                      item['history'] as WatchHistory,
                      episode: item['episode'] as Map<String, dynamic>?,
                    ),
                  );
                },
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              'Error loading watch history',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
          ),
        );
  }

  List<Map<String, dynamic>> _expandEpisodes(List<WatchHistory> histories) {
    final expanded = <Map<String, dynamic>>[];

    for (final history in histories) {
      final isSeries =
          history.contentType.contains('series') ||
          history.contentType.contains('show');

      if (isSeries && history.seriesProgress != null) {
        for (final season in history.seriesProgress!) {
          for (final episode in season.episodes) {
            expanded.add({
              'history': history,
              'episode': {
                'seasonNumber': season.seasonNumber,
                'episodeNumber': episode.episodeNumber,
                'episodeTitle': episode.episodeTitle,
                'episodeId': episode.episodeId,
                'progress': episode.progress,
              },
            });
          }
        }
      } else {
        expanded.add({'history': history, 'episode': null});
      }
    }

    return expanded.reversed.toList();
  }

  void _deleteWatchHistory(String id) {
    ref.read(watchHistoryNotifierProvider.notifier).deleteHistory(id).then((_) {
      ref.invalidate(
        watchHistoryListProvider((
          status: statuses[_tabController.index].value,
          limit: 50,
          page: _currentPage,
        )),
      );
    });
  }

  void _navigateToContent(
    WatchHistory history, {
    Map<String, dynamic>? episode,
  }) {
    int? initialSeasonNumber;
    int? initialEpisodeNumber;
    String? initialEpisodeId;
    Duration? initialProgress;

    final isSeries =
        history.contentType.contains('series') ||
        history.contentType.contains('show');

    if (isSeries && episode != null) {
      initialSeasonNumber = episode['seasonNumber'] as int?;
      initialEpisodeNumber = episode['episodeNumber'] as int?;
      initialEpisodeId = episode['episodeId'] as String?;
      final progress = episode['progress'] as ProgressInfo?;
      if (progress != null && progress.currentTime > 0) {
        initialProgress = Duration(seconds: progress.currentTime.toInt());
      }
    } else if (!isSeries && history.progress != null) {
      if (history.progress!.currentTime > 0) {
        initialProgress = Duration(
          seconds: history.progress!.currentTime.toInt(),
        );
      }
    }

    final contentItem = ContentItem(
      id: history.contentId,
      title: history.contentTitle,
      posterUrl: '',
      serverName: history.serverName,
      serverType: history.serverType,
      contentType: history.contentType,
      initialSeasonNumber: initialSeasonNumber,
      initialEpisodeNumber: initialEpisodeNumber,
      initialEpisodeId: initialEpisodeId,
      initialProgress: initialProgress,
    );

    context.push(ContentDetailsScreen.path, extra: contentItem).then((_) {
      ref.invalidate(
        watchHistoryListProvider((
          status: statuses[_tabController.index].value,
          limit: 50,
          page: _currentPage,
        )),
      );
    });
  }
}
