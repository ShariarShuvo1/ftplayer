import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/right_drawer.dart';
import '../../../core/widgets/search_overlay.dart';
import '../../../core/utils/vibration_helper.dart';
import '../../../state/search/search_provider.dart';
import '../../../state/ftp/working_ftp_servers_provider.dart';
import '../../../state/settings/vibration_settings_provider.dart';
import '../../content_details/presentation/content_details_screen.dart';
import '../../home/data/home_models.dart';
import '../../home/presentation/widgets/universal_poster_image.dart';
import '../data/search_models.dart';

class SearchResultScreen extends ConsumerStatefulWidget {
  const SearchResultScreen({required this.initialQuery, super.key});

  static const path = '/search';

  final String initialQuery;

  @override
  ConsumerState<SearchResultScreen> createState() => _SearchResultScreenState();
}

class _SearchResultScreenState extends ConsumerState<SearchResultScreen>
    with SingleTickerProviderStateMixin {
  bool _showSearch = false;
  late TextEditingController _searchController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(searchQueryProvider.notifier).state = widget.initialQuery;
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    setState(() {});
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled && vibrationSettings.vibrateOnTabChange) {
      VibrationHelper.vibrate(vibrationSettings.strength);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  bool isLocalFile(String url) {
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme) {
      return uri.scheme == 'file';
    }
    return !(url.startsWith('http://') || url.startsWith('https://'));
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
      _searchController.text = query;
    });
    ref.read(searchQueryProvider.notifier).state = query;
  }

  void _handleSearchClose(String query) {
    setState(() {
      _showSearch = false;
      _searchController.text = query;
    });
  }

  List<SearchResult> _filterResults(List<SearchResult> results) {
    final filterIndex = _tabController.index;
    if (filterIndex == 0) {
      return results;
    } else if (filterIndex == 1) {
      return results.where((r) => r.contentType == 'movie').toList();
    } else if (filterIndex == 2) {
      return results.where((r) => r.contentType == 'series').toList();
    }
    return results;
  }

  void _navigateToContent(SearchResult result) {
    final contentItem = ContentItem(
      id: result.id,
      title: result.title,
      posterUrl: result.posterUrl,
      serverName: result.serverName,
      serverType: result.serverType,
      year: result.year,
      quality: result.quality,
      contentType: result.contentType,
      description: result.description,
    );

    context.push(ContentDetailsScreen.path, extra: contentItem);
  }

  @override
  Widget build(BuildContext context) {
    final searchResultsAsync = ref.watch(searchResultsProvider);
    final workingServersAsync = ref.watch(workingFtpServersProvider);

    return AppScaffold(
      title: 'Search Results',
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
      bottom: null,
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
                child: GestureDetector(
                  onTap: _toggleSearch,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.manage_search,
                          color: AppColors.textMid,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '"${_searchController.text}"',
                            style: const TextStyle(
                              color: AppColors.textHigh,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Container(
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  tabs: const [
                    Tab(
                      height: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.apps_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('All'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.movie_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('Movie'),
                        ],
                      ),
                    ),
                    Tab(
                      height: 32,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.tv_outlined, size: 16),
                          SizedBox(width: 6),
                          Text('TV Series'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: searchResultsAsync.when(
                  data: (data) {
                    final filteredResults = _filterResults(data.results);
                    if (filteredResults.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search_off,
                              size: 64,
                              color: AppColors.textLow,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              data.query.isEmpty
                                  ? 'Enter a search term'
                                  : 'No results found',
                              style: const TextStyle(
                                color: AppColors.textMid,
                                fontSize: 16,
                              ),
                            ),
                            if (data.query.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Try searching for something else',
                                style: const TextStyle(
                                  color: AppColors.textLow,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(searchResultsProvider);
                        await ref.read(searchResultsProvider.future);
                      },
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                              childAspectRatio: 2 / 3.2,
                            ),
                        itemCount: filteredResults.length,
                        itemBuilder: (context, index) {
                          return _buildSearchResultItem(
                            filteredResults[index],
                            () => _navigateToContent(filteredResults[index]),
                          );
                        },
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
                          'Searching...',
                          style: TextStyle(
                            color: AppColors.textMid,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  error: (error, stack) {
                    if (error.toString().contains('NO_ENABLED_SERVERS')) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.storage,
                              size: 64,
                              color: AppColors.textLow,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No servers enabled',
                              style: TextStyle(
                                color: AppColors.textMid,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'Enable working FTP servers from menu to search content',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.textLow,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Center(
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
                            'Search failed',
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
                                ref.invalidate(searchResultsProvider),
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
            ],
          ),
          if (_showSearch)
            Positioned.fill(
              child: SearchOverlay(
                onClose: _handleSearchClose,
                onSearch: _handleSearch,
                initialQuery: _searchController.text,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(SearchResult result, VoidCallback onTap) {
    final placeholderIcon = result.contentType == 'series'
        ? Icons.tv
        : Icons.movie;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Stack(
              children: [
                UniversalPosterImage(
                  imageUrl: result.posterUrl,
                  isLocalFile: isLocalFile(result.posterUrl),
                  placeholderIcon: placeholderIcon,
                  borderRadius: 8,
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      result.contentType == 'series' ? Icons.tv : Icons.movie,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      result.serverName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (result.quality != null && result.quality!.isNotEmpty)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        result.quality!,
                        style: const TextStyle(
                          color: AppColors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            result.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textHigh,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          if (result.year != null && result.year!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                result.year!,
                style: const TextStyle(
                  color: AppColors.textLow,
                  fontSize: 10,
                  height: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
