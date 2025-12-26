import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/right_drawer.dart';
import '../../../core/widgets/search_overlay.dart';
import '../../../state/downloads/download_provider.dart';
import '../../../state/connectivity/connectivity_provider.dart';
import '../../../state/ftp/working_ftp_servers_provider.dart';
import '../../home/data/home_models.dart';
import '../../content_details/presentation/content_details_screen.dart';
import '../../search/presentation/search_result_screen.dart';
import '../data/download_models.dart';
import 'widgets/download_list_item.dart';

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});

  static const path = '/downloads';

  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
    if (query.isNotEmpty) {
      setState(() {
        _showSearch = false;
      });
      context.push(SearchResultScreen.path, extra: query);
    }
  }

  void _handleSearchClose(String query) {
    setState(() {
      _showSearch = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(offlineModeProvider);
    final workingServersAsync = ref.watch(workingFtpServersProvider);

    ref.listen<bool>(offlineModeProvider, (previous, next) {
      if (previous == false && next == true) {
        ref.read(downloadNotifierProvider.notifier).pauseAllDownloads();
      }
    });

    final tabs = isOffline
        ? const [
            Tab(
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Downloaded'),
                ],
              ),
            ),
            Tab(
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.downloading_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('In Progress'),
                ],
              ),
            ),
          ]
        : const [
            Tab(
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.downloading_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('In Progress'),
                ],
              ),
            ),
            Tab(
              height: 32,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.download_done_rounded, size: 16),
                  SizedBox(width: 6),
                  Text('Downloaded'),
                ],
              ),
            ),
          ];

    final children = isOffline
        ? [_buildDownloadedTab(isOffline), _buildInProgressTab(isOffline)]
        : [_buildInProgressTab(isOffline), _buildDownloadedTab(isOffline)];

    return AppScaffold(
      title: 'Downloads',
      endDrawer: const RightDrawer(),
      actions: [
        workingServersAsync.when(
          data: (workingServers) => IconButton(
            tooltip: isOffline ? 'Search disabled in offline mode' : 'Search',
            onPressed: isOffline ? null : _toggleSearch,
            icon: const Icon(Icons.search),
            color: isOffline ? AppColors.textLow : AppColors.primary,
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
            isScrollable: false,
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
            tabs: tabs,
          ),
        ),
      ),
      padding: EdgeInsets.zero,
      body: Stack(
        children: [
          TabBarView(controller: _tabController, children: children),
          if (_showSearch)
            Positioned.fill(
              child: SearchOverlay(
                onClose: _handleSearchClose,
                onSearch: _handleSearch,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDownloadedTab(bool isOffline) {
    final downloadsAsync = ref.watch(downloadedContentProvider);

    return downloadsAsync.when(
      data: (downloads) {
        if (downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.download_for_offline_outlined,
                  size: 64,
                  color: AppColors.textLow,
                ),
                const SizedBox(height: 16),
                Text(
                  'No downloads yet',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.textMid),
                ),
                const SizedBox(height: 8),
                Text(
                  'Downloaded content will appear here',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textLow),
                ),
              ],
            ),
          );
        }

        final sortedDownloads = List<DownloadedContent>.from(downloads)
          ..sort((a, b) => b.downloadedAt.compareTo(a.downloadedAt));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sortedDownloads.length,
          itemBuilder: (context, index) {
            final download = sortedDownloads[index];
            return DownloadListItem(
              download: download,
              onTap: () => _navigateToContent(download, isOffline),
              onDelete: () => _confirmDelete(download),
            );
          },
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading downloads...',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMid),
            ),
          ],
        ),
      ),
      error: (error, _) => Center(
        child: Text(
          'Error loading downloads',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
        ),
      ),
    );
  }

  Widget _buildInProgressTab(bool isOffline) {
    final tasksAsync = ref.watch(downloadTasksProvider);

    return tasksAsync.when(
      data: (tasks) {
        final activeTasks = tasks
            .where(
              (t) =>
                  t.status == DownloadStatus.downloading ||
                  t.status == DownloadStatus.queued ||
                  t.status == DownloadStatus.paused ||
                  t.status == DownloadStatus.failed,
            )
            .toList();

        if (activeTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_download_outlined,
                  size: 64,
                  color: AppColors.textLow,
                ),
                const SizedBox(height: 16),
                Text(
                  'No active downloads',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: AppColors.textMid),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start downloading content to watch offline',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.textLow),
                ),
              ],
            ),
          );
        }

        final sortedTasks = List<DownloadTask>.from(activeTasks)
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sortedTasks.length,
          itemBuilder: (context, index) {
            final task = sortedTasks[index];
            return DownloadTaskItem(task: task, disablePauseResume: isOffline);
          },
        );
      },
      loading: () => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              'Loading downloads...',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMid),
            ),
          ],
        ),
      ),
      error: (error, _) => Center(
        child: Text(
          'Error loading downloads',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.danger),
        ),
      ),
    );
  }

  void _navigateToContent(DownloadedContent download, bool isOffline) {
    final workingServersAsync = ref.read(workingFtpServersProvider);

    workingServersAsync.when(
      data: (servers) {
        final serverWorking = servers.any((s) => s.name == download.serverName);
        final shouldUseOnlineMode = !isOffline && serverWorking;

        Map<String, dynamic>? metadata;
        if (!shouldUseOnlineMode && download.metadata != null) {
          metadata = Map<String, dynamic>.from(download.metadata!);
          if (download.localPosterPath != null) {
            metadata['localPosterPath'] = download.localPosterPath;
          }
        }

        final contentItem = ContentItem(
          id: download.contentId,
          title: download.isEpisode
              ? (download.seriesTitle ?? download.title)
              : download.title,
          posterUrl: download.localPosterPath ?? download.posterUrl,
          serverName: download.serverName,
          serverType: download.serverType,
          year: download.year,
          quality: download.quality,
          rating: download.rating,
          contentType: download.contentType,
          description: download.description,
          initialSeasonNumber: download.seasonNumber,
          initialEpisodeNumber: download.episodeNumber,
          initialData: metadata,
        );

        context.push(ContentDetailsScreen.path, extra: contentItem);
      },
      loading: () {
        Map<String, dynamic>? metadata;
        if (isOffline && download.metadata != null) {
          metadata = Map<String, dynamic>.from(download.metadata!);
          if (download.localPosterPath != null) {
            metadata['localPosterPath'] = download.localPosterPath;
          }
        }

        final contentItem = ContentItem(
          id: download.contentId,
          title: download.isEpisode
              ? (download.seriesTitle ?? download.title)
              : download.title,
          posterUrl: download.localPosterPath ?? download.posterUrl,
          serverName: download.serverName,
          serverType: download.serverType,
          year: download.year,
          quality: download.quality,
          rating: download.rating,
          contentType: download.contentType,
          description: download.description,
          initialSeasonNumber: download.seasonNumber,
          initialEpisodeNumber: download.episodeNumber,
          initialData: metadata,
        );

        context.push(ContentDetailsScreen.path, extra: contentItem);
      },
      error: (_, _) {
        Map<String, dynamic>? metadata;
        if (download.metadata != null) {
          metadata = Map<String, dynamic>.from(download.metadata!);
          if (download.localPosterPath != null) {
            metadata['localPosterPath'] = download.localPosterPath;
          }
        }

        final contentItem = ContentItem(
          id: download.contentId,
          title: download.isEpisode
              ? (download.seriesTitle ?? download.title)
              : download.title,
          posterUrl: download.localPosterPath ?? download.posterUrl,
          serverName: download.serverName,
          serverType: download.serverType,
          year: download.year,
          quality: download.quality,
          rating: download.rating,
          contentType: download.contentType,
          description: download.description,
          initialSeasonNumber: download.seasonNumber,
          initialEpisodeNumber: download.episodeNumber,
          initialData: metadata,
        );

        context.push(ContentDetailsScreen.path, extra: contentItem);
      },
    );
  }

  void _confirmDelete(DownloadedContent download) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Delete Download',
          style: TextStyle(color: AppColors.textHigh),
        ),
        content: Text(
          'Are you sure you want to delete "${download.isEpisode ? download.displayTitle : download.title}"? This will remove the downloaded file.',
          style: const TextStyle(color: AppColors.textMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMid),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref
                  .read(downloadNotifierProvider.notifier)
                  .deleteDownload(download.id);
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
