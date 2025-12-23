import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/right_drawer.dart';
import '../../../core/widgets/search_overlay.dart';
import '../../../app/theme/app_colors.dart';
import '../../../state/home/home_content_provider.dart';
import '../../search/presentation/search_result_screen.dart';
import 'widgets/content_section.dart';
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
    final homeContentAsync = ref.watch(homeContentProvider);

    return AppScaffold(
      title: 'FTPlayer',
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
      body: Stack(
        children: [
          homeContentAsync.when(
            data: (homeContent) {
              final hasFeatured = homeContent.featured.isNotEmpty;
              final hasTrending = homeContent.trending.isNotEmpty;
              final hasLatest = homeContent.latest.isNotEmpty;
              final hasTvSeries = homeContent.tvSeries.isNotEmpty;
              final hasAnyContent =
                  hasFeatured || hasTrending || hasLatest || hasTvSeries;

              if (!hasAnyContent) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 64, color: AppColors.textLow),
                      SizedBox(height: 16),
                      Text(
                        'No servers available',
                        style: TextStyle(
                          color: AppColors.textMid,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
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
                  ref.invalidate(homeContentProvider);
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
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    style: TextStyle(color: AppColors.textMid, fontSize: 14),
                  ),
                ],
              ),
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load content',
                    style: TextStyle(color: AppColors.textMid, fontSize: 16),
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
                    onPressed: () => ref.invalidate(homeContentProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.black,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
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
