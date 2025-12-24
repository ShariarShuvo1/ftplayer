import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/right_drawer.dart';
import '../../../core/widgets/search_overlay.dart';
import '../../../core/widgets/offline_mode_banner.dart';
import '../../../app/theme/app_colors.dart';
import '../../../state/home/home_content_provider.dart';
import '../../../state/ftp/working_ftp_servers_provider.dart';
import '../../../state/ftp/ftp_availability_controller.dart';
import '../../../state/connectivity/connectivity_provider.dart';
import '../../../state/downloads/download_provider.dart';
import '../../search/presentation/search_result_screen.dart';
import '../../ftp_servers/presentation/server_scan_screen.dart';
import '../data/home_models.dart';
import 'widgets/content_section.dart';
import 'widgets/offline_content_grid.dart';
import 'widgets/featured_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const path = '/home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _showSearch = false;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
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
    if (mounted) {
      context.push(SearchResultScreen.path, extra: query);
    }
  }

  void _handleSearchClose(String query) {
    setState(() {
      _showSearch = false;
      _searchText = query;
    });
  }

  List<ContentItem> _buildOfflineContentItems(List<dynamic> downloads) {
    final groupedByContent = <String, dynamic>{};
    for (final download in downloads) {
      groupedByContent[download.contentId] ??= download;
    }

    return groupedByContent.values.map((download) {
      Map<String, dynamic>? metadata;
      if (download.metadata != null) {
        metadata = Map<String, dynamic>.from(download.metadata!);
        if (download.localPosterPath != null) {
          metadata['localPosterPath'] = download.localPosterPath;
        }
      }

      return ContentItem(
        id: download.contentId,
        title: download.isEpisode
            ? (download.seriesTitle ?? download.title)
            : download.title,
        posterUrl: download.localPosterPath ?? download.posterUrl,
        serverName: download.serverName,
        serverType: download.serverType,
        contentType: download.contentType,
        description: download.description,
        initialSeasonNumber: download.seasonNumber,
        initialEpisodeNumber: download.episodeNumber,
        initialData: metadata,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(offlineModeProvider, (previous, next) {
      if (previous == true && next == false) {
        ref.read(ftpAvailabilityControllerProvider.notifier).reset();
        context.go(ServerScanScreen.path);
      }
    });

    final homeContentAsync = ref.watch(homeContentProvider);
    final workingServersAsync = ref.watch(workingFtpServersProvider);
    final downloadedContentAsync = ref.watch(downloadedContentProvider);
    final isOffline = ref.watch(offlineModeProvider);

    return AppScaffold(
      title: 'FTPlayer',
      endDrawer: const RightDrawer(),
      actions: [
        workingServersAsync.when(
          data: (workingServers) => IconButton(
            tooltip: isOffline
                ? 'Search disabled in offline mode'
                : (workingServers.isEmpty
                      ? 'Add working FTP servers to search'
                      : 'Search'),
            onPressed: (isOffline || workingServers.isEmpty)
                ? null
                : _toggleSearch,
            icon: const Icon(Icons.search),
            color: (isOffline || workingServers.isEmpty)
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
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu),
              color: AppColors.primary,
            );
          },
        ),
      ],
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: homeContentAsync.when(
                  data: (homeContent) {
                    final hasFeatured = homeContent.featured.isNotEmpty;
                    final hasTrending = homeContent.trending.isNotEmpty;
                    final hasLatest = homeContent.latest.isNotEmpty;
                    final hasTvSeries = homeContent.tvSeries.isNotEmpty;
                    final hasAnyContent =
                        hasFeatured || hasTrending || hasLatest || hasTvSeries;

                    if (!hasAnyContent) {
                      if (isOffline) {
                        return downloadedContentAsync.when(
                          data: (downloads) {
                            if (downloads.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.cloud_off,
                                      size: 64,
                                      color: AppColors.textLow,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'You are offline',
                                      style: TextStyle(
                                        color: AppColors.textMid,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'No downloaded content available',
                                      style: TextStyle(
                                        color: AppColors.textLow,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            final offlineItems = _buildOfflineContentItems(
                              downloads,
                            );
                            return ListView(
                              children: [
                                OfflineContentGrid(
                                  title: 'My Downloads',
                                  items: offlineItems,
                                  icon: Icons.download_done,
                                ),
                                const SizedBox(height: 32),
                              ],
                            );
                          },
                          loading: () => const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          ),
                          error: (_, _) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off,
                                  size: 64,
                                  color: AppColors.textLow,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'You are offline',
                                  style: TextStyle(
                                    color: AppColors.textMid,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Connect to internet to load content',
                                  style: TextStyle(
                                    color: AppColors.textLow,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 64,
                              color: AppColors.textLow,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No servers available',
                              style: TextStyle(
                                color: AppColors.textMid,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add working FTP servers to see content',
                              style: TextStyle(
                                color: AppColors.textLow,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        if (!isOffline) {
                          ref.invalidate(homeContentProvider);
                        }
                      },
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      child: ListView(
                        children: [
                          if (hasFeatured) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 220,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                physics: const PageScrollPhysics(),
                                itemCount: homeContent.featured.length,
                                itemBuilder: (context, index) {
                                  return FeaturedCard(
                                    content: homeContent.featured[index],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                          if (hasTrending) ...[
                            ContentSection(
                              title: 'Trending Now',
                              items: homeContent.trending,
                              icon: Icons.local_fire_department,
                            ),
                            const SizedBox(height: 32),
                          ],
                          if (hasLatest) ...[
                            ContentSection(
                              title: 'Latest Movies',
                              items: homeContent.latest,
                              icon: Icons.new_releases,
                            ),
                            const SizedBox(height: 32),
                          ],
                          if (hasTvSeries) ...[
                            ContentSection(
                              title: 'TV Series',
                              items: homeContent.tvSeries,
                              icon: Icons.tv,
                            ),
                            const SizedBox(height: 32),
                          ],
                        ],
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text(
                          'Loading content...',
                          style: TextStyle(
                            color: AppColors.textMid,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  error: (error, stack) {
                    if (isOffline) {
                      return downloadedContentAsync.when(
                        data: (downloads) {
                          if (downloads.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_off,
                                    size: 64,
                                    color: AppColors.textLow,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'You are offline',
                                    style: TextStyle(
                                      color: AppColors.textMid,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No downloaded content available',
                                    style: TextStyle(
                                      color: AppColors.textLow,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          final offlineItems = _buildOfflineContentItems(
                            downloads,
                          );
                          return ListView(
                            children: [
                              OfflineContentGrid(
                                title: 'My Downloads',
                                items: offlineItems,
                                icon: Icons.download_done,
                              ),
                              const SizedBox(height: 32),
                            ],
                          );
                        },
                        loading: () => const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                        error: (_, _) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_off,
                                size: 64,
                                color: AppColors.textLow,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'You are offline',
                                style: TextStyle(
                                  color: AppColors.textMid,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Connect to internet to load content',
                                style: TextStyle(
                                  color: AppColors.textLow,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppColors.danger,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load content',
                            style: TextStyle(
                              color: AppColors.textMid,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              error.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textLow,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () =>
                                ref.invalidate(homeContentProvider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: AppColors.black,
                            ),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const OfflineModeBanner(),
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
}
