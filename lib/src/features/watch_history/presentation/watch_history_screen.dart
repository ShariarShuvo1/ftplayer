import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/utils/vibration_helper.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/right_drawer.dart';
import '../../../core/widgets/search_overlay.dart';
import '../../../state/watch_history/watch_history_provider.dart';
import '../../../state/ftp/working_ftp_servers_provider.dart';
import '../../../state/connectivity/connectivity_provider.dart';
import '../../../state/downloads/download_provider.dart';
import '../../../state/settings/vibration_settings_provider.dart';
import '../data/watch_history_models.dart';
import '../../../features/home/data/home_models.dart';
import '../../../features/content_details/presentation/content_details_screen.dart';
import '../../../features/search/presentation/search_result_screen.dart';
import 'widgets/watch_history_list_item.dart';
import 'widgets/watch_history_filter_bar.dart';
import 'widgets/watch_history_series_card.dart';

class WatchHistoryScreen extends ConsumerStatefulWidget {
  const WatchHistoryScreen({super.key});

  static const path = '/watch-history';

  @override
  ConsumerState<WatchHistoryScreen> createState() => _WatchHistoryScreenState();
}

class _WatchHistoryScreenState extends ConsumerState<WatchHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showSearch = false;
  String _searchText = '';
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  final Map<String, List<Map<String, dynamic>>> _cachedItems = {};
  final Map<String, int> _currentPages = {};
  final Map<String, bool> _hasMoreData = {};

  final Map<String, String> _tabSearchQueries = {};
  final Map<String, SortOption> _tabSortOptions = {};
  final Map<String, bool> _tabSortAscending = {};
  final Map<String, GroupByOption> _tabGroupByOptions = {};
  final Map<String, String?> _tabServerFilters = {};
  final Map<String, ContentTypeFilter> _tabContentTypeFilters = {};
  final Map<String, Set<String>> _tabAvailableServers = {};
  final Map<String, String?> _tabExpandedCardIds = {};

  final List<WatchStatus> statuses = [
    WatchStatus.planned,
    WatchStatus.watching,
    WatchStatus.completed,
    WatchStatus.onHold,
    WatchStatus.dropped,
  ];

  String get _currentTabKey => statuses[_tabController.index].value;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: statuses.length, vsync: this);
    _tabController.addListener(() async {
      if (!_tabController.indexIsChanging) {
        final vibrationSettings = ref.read(vibrationSettingsProvider);
        if (vibrationSettings.enabled && vibrationSettings.vibrateOnTabChange) {
          await VibrationHelper.vibrate(vibrationSettings.strength);
        }
      }
    });
    for (final status in statuses) {
      _currentPages[status.value] = 1;
      _cachedItems[status.value] = [];
      _hasMoreData[status.value] = true;
      _tabSearchQueries[status.value] = '';
      _tabSortOptions[status.value] = SortOption.lastWatched;
      _tabSortAscending[status.value] = false;
      _tabGroupByOptions[status.value] = GroupByOption.episode;
      _tabServerFilters[status.value] = null;
      _tabContentTypeFilters[status.value] = ContentTypeFilter.all;
      _tabAvailableServers[status.value] = {};
      _tabExpandedCardIds[status.value] = null;
    }
    _tabController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final status in statuses) {
        ref.invalidate(
          watchHistoryListProvider((status: status.value, limit: 50, page: 1)),
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_isLoadingMore &&
        _scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      final hasMore = _hasMoreData[_currentTabKey] ?? true;
      if (hasMore) {
        _loadMoreItems();
      }
    }
  }

  void _loadMoreItems() {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _currentPages[_currentTabKey] = (_currentPages[_currentTabKey] ?? 1) + 1;
    });
  }

  void _resetTab(String tabKey) {
    setState(() {
      _currentPages[tabKey] = 1;
      _cachedItems[tabKey] = [];
      _hasMoreData[tabKey] = true;
      _isLoadingMore = false;
    });
  }

  void _toggleSearch() {
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled && vibrationSettings.vibrateOnAppbar) {
      VibrationHelper.vibrate(vibrationSettings.strength);
    }
    setState(() {
      _showSearch = !_showSearch;
    });
  }

  void _handleSearch(String query) {
    setState(() {
      _showSearch = false;
    });
    context.pushReplacement(SearchResultScreen.path, extra: query);
  }

  void _handleSearchClose(String query) {
    setState(() {
      _showSearch = false;
      _searchText = query;
    });
  }

  void _confirmDeleteAll() {
    final currentStatus = statuses[_tabController.index];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.surfaceAlt, width: 1),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: AppColors.danger,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete All',
                style: TextStyle(
                  color: AppColors.textHigh,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all ${currentStatus.label.toLowerCase()} items? This action cannot be undone.',
          style: const TextStyle(
            color: AppColors.textMid,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () {
              final vibrationSettings = ref.read(vibrationSettingsProvider);
              if (vibrationSettings.enabled &&
                  vibrationSettings.vibrateOnAppbar) {
                VibrationHelper.vibrate(vibrationSettings.strength);
              }
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: AppColors.surfaceAlt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textMid,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              final vibrationSettings = ref.read(vibrationSettingsProvider);
              if (vibrationSettings.enabled &&
                  vibrationSettings.vibrateOnAppbar) {
                VibrationHelper.vibrate(vibrationSettings.strength);
              }
              Navigator.of(context).pop();
              _deleteAllByStatus(currentStatus);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              backgroundColor: AppColors.danger.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.danger, width: 1),
              ),
            ),
            child: const Text(
              'Delete All',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workingServersAsync = ref.watch(workingFtpServersProvider);

    return AppScaffold(
      title: 'Watch History',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          final vibrationSettings = ref.read(vibrationSettingsProvider);
          if (vibrationSettings.enabled && vibrationSettings.vibrateOnAppbar) {
            VibrationHelper.vibrate(vibrationSettings.strength);
          }
          context.pop();
        },
      ),
      endDrawer: const RightDrawer(),
      actions: [
        IconButton(
          tooltip: 'Delete All',
          onPressed: (_cachedItems[_currentTabKey]?.isNotEmpty ?? false)
              ? () {
                  final vibrationSettings = ref.read(vibrationSettingsProvider);
                  if (vibrationSettings.enabled &&
                      vibrationSettings.vibrateOnAppbar) {
                    VibrationHelper.vibrate(vibrationSettings.strength);
                  }
                  _confirmDeleteAll();
                }
              : null,
          icon: const Icon(Icons.delete_sweep),
          color: (_cachedItems[_currentTabKey]?.isNotEmpty ?? false)
              ? AppColors.primary
              : AppColors.textLow,
        ),
        workingServersAsync.when(
          data: (workingServers) => IconButton(
            tooltip: workingServers.isEmpty
                ? 'Add working FTP servers to search'
                : 'Search',
            onPressed: workingServers.isEmpty ? null : _toggleSearch,
            icon: const Icon(Icons.search),
            color: workingServers.isEmpty
                ? AppColors.textLow
                : AppColors.primary,
          ),
          loading: () => const SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
          ),
          error: (_, _) => IconButton(
            tooltip: 'Search',
            onPressed: _toggleSearch,
            icon: const Icon(Icons.search),
            color: AppColors.primary,
          ),
        ),
        Builder(
          builder: (context) {
            return IconButton(
              tooltip: 'Menu',
              onPressed: () {
                final vibrationSettings = ref.read(vibrationSettingsProvider);
                if (vibrationSettings.enabled &&
                    vibrationSettings.vibrateOnAppbar) {
                  VibrationHelper.vibrate(vibrationSettings.strength);
                }
                Scaffold.of(context).openEndDrawer();
              },
              icon: const Icon(Icons.menu),
              color: AppColors.primary,
            );
          },
        ),
      ],
      padding: EdgeInsets.zero,
      body: Stack(
        children: [
          Column(
            children: [
              Container(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tabs: statuses
                      .map(
                        (status) => Tab(
                          height: 32,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_getStatusIcon(status), size: 18),
                                const SizedBox(width: 8),
                                Text(status.label),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: statuses.map((status) {
                    return _buildWatchHistoryList(status);
                  }).toList(),
                ),
              ),
            ],
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
    final tabKey = status.value;
    final currentPage = _currentPages[tabKey] ?? 1;
    final searchQuery = _tabSearchQueries[tabKey] ?? '';
    final sortOption = _tabSortOptions[tabKey] ?? SortOption.lastWatched;
    final sortAscending = _tabSortAscending[tabKey] ?? false;
    final groupByOption = _tabGroupByOptions[tabKey] ?? GroupByOption.episode;
    final serverFilter = _tabServerFilters[tabKey];
    final contentTypeFilter =
        _tabContentTypeFilters[tabKey] ?? ContentTypeFilter.all;
    final availableServers = _tabAvailableServers[tabKey]?.toList() ?? [];

    return ref
        .watch(
          watchHistoryListProvider((
            status: tabKey,
            limit: 50,
            page: currentPage,
          )),
        )
        .when(
          data: (histories) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              for (final h in histories) {
                _tabAvailableServers[tabKey]?.add(h.serverType);
              }

              final expandedItems = _expandAndSortEpisodes(histories);

              if (currentPage == 1) {
                _cachedItems[tabKey] = expandedItems;
              } else {
                final existingIds = _cachedItems[tabKey]!.map((item) {
                  final history = item['history'] as WatchHistory;
                  final episode = item['episode'] as Map<String, dynamic>?;
                  if (episode != null) {
                    return '${history.contentId}_${episode['episodeId']}';
                  }
                  return history.contentId;
                }).toSet();

                for (final newItem in expandedItems) {
                  final history = newItem['history'] as WatchHistory;
                  final episode = newItem['episode'] as Map<String, dynamic>?;
                  final itemId = episode != null
                      ? '${history.contentId}_${episode['episodeId']}'
                      : history.contentId;

                  if (!existingIds.contains(itemId)) {
                    _cachedItems[tabKey]!.add(newItem);
                  }
                }
              }

              if (expandedItems.length < 50) {
                _hasMoreData[tabKey] = false;
              }

              if (_isLoadingMore) {
                _isLoadingMore = false;
              }

              if (mounted) {
                setState(() {});
              }
            });

            final allItems = _cachedItems[tabKey] ?? [];
            final filteredItems = _applyFiltersAndSort(
              allItems,
              searchQuery,
              sortOption,
              sortAscending,
              groupByOption,
              serverFilter,
              contentTypeFilter,
            );

            return Column(
              children: [
                WatchHistoryFilterBar(
                  searchQuery: searchQuery,
                  sortOption: sortOption,
                  sortAscending: sortAscending,
                  groupByOption: groupByOption,
                  serverFilter: serverFilter,
                  contentTypeFilter: contentTypeFilter,
                  availableServers: availableServers,
                  onSearchChanged: (value) {
                    setState(() {
                      _tabSearchQueries[tabKey] = value;
                    });
                  },
                  onSortChanged: (value) {
                    setState(() {
                      _tabSortOptions[tabKey] = value;
                    });
                  },
                  onSortDirectionChanged: () {
                    setState(() {
                      _tabSortAscending[tabKey] =
                          !(_tabSortAscending[tabKey] ?? false);
                    });
                  },
                  onGroupByChanged: (value) {
                    setState(() {
                      _tabGroupByOptions[tabKey] = value;
                    });
                  },
                  onServerFilterChanged: (value) {
                    setState(() {
                      _tabServerFilters[tabKey] = value;
                    });
                  },
                  onContentTypeFilterChanged: (value) {
                    setState(() {
                      _tabContentTypeFilters[tabKey] = value;
                    });
                  },
                ),
                Expanded(
                  child: filteredItems.isEmpty && currentPage == 1
                      ? Center(
                          child: Text(
                            searchQuery.isNotEmpty
                                ? 'No results found'
                                : 'No ${status.label.toLowerCase()} items',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppColors.textMid),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async {
                            _resetTab(tabKey);
                            return ref.refresh(
                              watchHistoryListProvider((
                                status: tabKey,
                                limit: 50,
                                page: 1,
                              )).future,
                            );
                          },
                          color: AppColors.primary,
                          backgroundColor: AppColors.surface,
                          child: ListView.builder(
                            key: PageStorageKey<String>(
                              'watch_history_$tabKey',
                            ),
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            itemCount:
                                filteredItems.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index >= filteredItems.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              AppColors.primary,
                                            ),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return _buildListItem(
                                filteredItems[index],
                                groupByOption,
                                tabKey,
                              );
                            },
                          ),
                        ),
                ),
              ],
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

  Widget _buildListItem(
    Map<String, dynamic> item,
    GroupByOption groupByOption,
    String tabKey,
  ) {
    final history = item['history'] as WatchHistory;
    final isSeries =
        history.contentType.contains('series') ||
        history.contentType.contains('show');
    final isOffline = ref.watch(offlineModeProvider);

    if (groupByOption == GroupByOption.series && isSeries) {
      final isDownloaded = isOffline
          ? ref.watch(
              isContentDownloadedProvider((
                contentId: history.contentId,
                seasonNumber: null,
                episodeNumber: null,
              )),
            )
          : true;

      final cardId = '${history.ftpServerId}_${history.contentId}';
      final isExpanded = _tabExpandedCardIds[tabKey] == cardId;

      return WatchHistorySeriesCard(
        watchHistory: history,
        isDownloaded: isDownloaded,
        isOffline: isOffline,
        isExpanded: isExpanded,
        onExpansionChanged: () {
          setState(() {
            _tabExpandedCardIds[tabKey] = isExpanded ? null : cardId;
          });
        },
        onDelete: () {
          _deleteWatchHistory(history.ftpServerId, history.contentId);
        },
        onTap: () => _navigateToSeries(history),
        onEpisodeTap: (seasonNumber, episodeNumber, episodeId) {
          _navigateToContent(
            history,
            episode: {
              'seasonNumber': seasonNumber,
              'episodeNumber': episodeNumber,
              'episodeId': episodeId,
            },
          );
        },
      );
    }

    final episodeInfo = item['episode'] as Map<String, dynamic>?;
    final isDownloaded = isOffline
        ? ref.watch(
            isContentDownloadedProvider((
              contentId: history.contentId,
              seasonNumber: episodeInfo?['seasonNumber'] as int?,
              episodeNumber: episodeInfo?['episodeNumber'] as int?,
            )),
          )
        : true;

    return WatchHistoryListItem(
      watchHistory: history,
      episodeInfo: episodeInfo,
      isDownloaded: isDownloaded,
      isOffline: isOffline,
      onDelete: () {
        if (isSeries && episodeInfo != null) {
          _deleteEpisodeFromHistory(
            history.ftpServerId,
            history.contentId,
            episodeInfo['seasonNumber'] as int,
            episodeInfo['episodeNumber'] as int,
          );
        } else {
          _deleteWatchHistory(history.ftpServerId, history.contentId);
        }
      },
      onTap: () => _navigateToContent(history, episode: episodeInfo),
    );
  }

  List<Map<String, dynamic>> _applyFiltersAndSort(
    List<Map<String, dynamic>> items,
    String searchQuery,
    SortOption sortOption,
    bool sortAscending,
    GroupByOption groupByOption,
    String? serverFilter,
    ContentTypeFilter contentTypeFilter,
  ) {
    var filtered = List<Map<String, dynamic>>.from(items);

    if (serverFilter != null) {
      filtered = filtered.where((item) {
        final history = item['history'] as WatchHistory;
        return history.serverType == serverFilter;
      }).toList();
    }

    if (contentTypeFilter != ContentTypeFilter.all) {
      filtered = filtered.where((item) {
        final history = item['history'] as WatchHistory;
        final isSeries =
            history.contentType.contains('series') ||
            history.contentType.contains('show');

        if (contentTypeFilter == ContentTypeFilter.movie) {
          return !isSeries;
        } else {
          return isSeries;
        }
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        final history = item['history'] as WatchHistory;
        final episode = item['episode'] as Map<String, dynamic>?;
        final title = history.contentTitle.toLowerCase();
        final episodeTitle =
            episode?['episodeTitle']?.toString().toLowerCase() ?? '';
        return title.contains(query) || episodeTitle.contains(query);
      }).toList();
    }

    if (groupByOption == GroupByOption.series) {
      final seriesMap = <String, Map<String, dynamic>>{};
      for (final item in filtered) {
        final history = item['history'] as WatchHistory;
        final isSeries =
            history.contentType.contains('series') ||
            history.contentType.contains('show');

        if (isSeries) {
          final key = '${history.ftpServerId}_${history.contentId}';
          if (!seriesMap.containsKey(key)) {
            seriesMap[key] = {
              'history': history,
              'episode': null,
              'lastModified': history.lastWatchedAt,
            };
          } else {
            final existingDate = seriesMap[key]!['lastModified'] as DateTime;
            if (history.lastWatchedAt.isAfter(existingDate)) {
              seriesMap[key]!['lastModified'] = history.lastWatchedAt;
            }
          }
        } else {
          final key = '${history.ftpServerId}_${history.contentId}_movie';
          seriesMap[key] = item;
        }
      }
      filtered = seriesMap.values.toList();
    }

    filtered.sort((a, b) {
      int result;
      switch (sortOption) {
        case SortOption.lastWatched:
          final aDate = a['lastModified'] as DateTime;
          final bDate = b['lastModified'] as DateTime;
          result = bDate.compareTo(aDate);
        case SortOption.title:
          final aHistory = a['history'] as WatchHistory;
          final bHistory = b['history'] as WatchHistory;
          result = aHistory.contentTitle.compareTo(bHistory.contentTitle);
        case SortOption.progress:
          final aHistory = a['history'] as WatchHistory;
          final bHistory = b['history'] as WatchHistory;
          final aProgress = _getItemProgress(a, aHistory);
          final bProgress = _getItemProgress(b, bHistory);
          result = bProgress.compareTo(aProgress);
      }
      return sortAscending ? -result : result;
    });

    return filtered;
  }

  double _getItemProgress(Map<String, dynamic> item, WatchHistory history) {
    final episode = item['episode'] as Map<String, dynamic>?;
    if (episode != null) {
      final progress = episode['progress'] as ProgressInfo?;
      return progress?.percentage ?? 0.0;
    }
    if (history.seriesProgress != null && history.seriesProgress!.isNotEmpty) {
      double totalCurrent = 0;
      double totalDuration = 0;
      for (final season in history.seriesProgress!) {
        for (final ep in season.episodes) {
          totalCurrent += ep.progress.currentTime;
          totalDuration += ep.progress.duration;
        }
      }
      return totalDuration > 0 ? (totalCurrent / totalDuration) * 100 : 0.0;
    }
    return history.progress?.percentage ?? 0.0;
  }

  void _navigateToSeries(WatchHistory history) {
    final isOffline = ref.read(offlineModeProvider);
    String? localPosterPath;
    Map<String, dynamic>? initialData;

    if (isOffline) {
      final downloadedContent = ref.read(
        downloadedContentItemProvider((
          contentId: history.contentId,
          seasonNumber: null,
          episodeNumber: null,
        )),
      );

      if (downloadedContent != null) {
        localPosterPath = downloadedContent.localPosterPath;
        if (downloadedContent.metadata != null) {
          initialData = Map<String, dynamic>.from(downloadedContent.metadata!);
          if (downloadedContent.localPosterPath != null) {
            initialData['posterUrl'] = downloadedContent.localPosterPath;
          }
        }
      }
    }

    final contentItem = ContentItem(
      id: history.contentId,
      title: history.contentTitle,
      posterUrl: localPosterPath ?? history.metadata?['posterUrl'] ?? '',
      serverName: history.serverName,
      serverType: history.serverType,
      contentType: history.contentType,
      initialData: initialData,
    );

    final tabKey = _currentTabKey;
    context.push(ContentDetailsScreen.path, extra: contentItem).then((_) {
      _resetTab(tabKey);
      ref.invalidate(
        watchHistoryListProvider((status: tabKey, limit: 50, page: 1)),
      );
    });
  }

  List<Map<String, dynamic>> _expandAndSortEpisodes(
    List<WatchHistory> histories,
  ) {
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
              'lastModified': episode.lastWatchedAt,
            });
          }
        }
      } else {
        expanded.add({
          'history': history,
          'episode': null,
          'lastModified': history.lastWatchedAt,
        });
      }
    }

    expanded.sort((a, b) {
      final aDate = a['lastModified'] as DateTime;
      final bDate = b['lastModified'] as DateTime;
      return bDate.compareTo(aDate);
    });

    return expanded;
  }

  void _deleteWatchHistory(String ftpServerId, String contentId) {
    final tabKey = _currentTabKey;
    ref
        .read(watchHistoryNotifierProvider.notifier)
        .deleteHistory(ftpServerId, contentId)
        .then((_) {
          _resetTab(tabKey);
          ref.invalidate(
            watchHistoryListProvider((status: tabKey, limit: 50, page: 1)),
          );
        });
  }

  void _deleteEpisodeFromHistory(
    String ftpServerId,
    String contentId,
    int seasonNumber,
    int episodeNumber,
  ) {
    final tabKey = _currentTabKey;
    ref
        .read(watchHistoryNotifierProvider.notifier)
        .deleteEpisodeFromHistory(
          ftpServerId,
          contentId,
          seasonNumber,
          episodeNumber,
        )
        .then((_) {
          _resetTab(tabKey);
          ref.invalidate(
            watchHistoryListProvider((status: tabKey, limit: 50, page: 1)),
          );
        });
  }

  void _deleteAllByStatus(WatchStatus status) {
    final tabKey = status.value;
    ref
        .read(watchHistoryNotifierProvider.notifier)
        .deleteAllByStatus(status)
        .then((_) {
          _resetTab(tabKey);
          ref.invalidate(
            watchHistoryListProvider((status: tabKey, limit: 50, page: 1)),
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

    Map<String, dynamic>? initialData;
    String? localPosterPath;
    final isOffline = ref.read(offlineModeProvider);
    if (isOffline) {
      final downloadedContent = ref.read(
        downloadedContentItemProvider((
          contentId: history.contentId,
          seasonNumber: initialSeasonNumber,
          episodeNumber: initialEpisodeNumber,
        )),
      );

      if (downloadedContent != null) {
        localPosterPath = downloadedContent.localPosterPath;
        if (downloadedContent.metadata != null) {
          initialData = Map<String, dynamic>.from(downloadedContent.metadata!);
          if (downloadedContent.localPosterPath != null) {
            initialData['posterUrl'] = downloadedContent.localPosterPath;
          }
        }
      }
    }

    final contentItem = ContentItem(
      id: history.contentId,
      title: history.contentTitle,
      posterUrl: localPosterPath ?? history.metadata?['posterUrl'] ?? '',
      serverName: history.serverName,
      serverType: history.serverType,
      contentType: history.contentType,
      initialSeasonNumber: initialSeasonNumber,
      initialEpisodeNumber: initialEpisodeNumber,
      initialEpisodeId: initialEpisodeId,
      initialProgress: initialProgress,
      initialData: initialData,
    );

    final tabKey = _currentTabKey;
    context.push(ContentDetailsScreen.path, extra: contentItem).then((_) {
      _resetTab(tabKey);
      ref.invalidate(
        watchHistoryListProvider((status: tabKey, limit: 50, page: 1)),
      );
    });
  }

  IconData _getStatusIcon(WatchStatus status) {
    switch (status) {
      case WatchStatus.planned:
        return Icons.schedule;
      case WatchStatus.watching:
        return Icons.play_circle;
      case WatchStatus.completed:
        return Icons.check_circle;
      case WatchStatus.onHold:
        return Icons.pause_circle;
      case WatchStatus.dropped:
        return Icons.cancel;
    }
  }
}
