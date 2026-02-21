import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/vibration_helper.dart';
import '../../../../state/settings/vibration_settings_provider.dart';

enum SortOption {
  lastWatched,
  title,
  progress;

  String get label {
    switch (this) {
      case SortOption.lastWatched:
        return 'Last Watched';
      case SortOption.title:
        return 'Title';
      case SortOption.progress:
        return 'Progress';
    }
  }

  IconData get icon {
    switch (this) {
      case SortOption.lastWatched:
        return Icons.schedule;
      case SortOption.title:
        return Icons.sort_by_alpha;
      case SortOption.progress:
        return Icons.bar_chart;
    }
  }
}

enum GroupByOption {
  episode,
  series;

  String get label {
    switch (this) {
      case GroupByOption.episode:
        return 'Episodes';
      case GroupByOption.series:
        return 'Series';
    }
  }

  IconData get icon {
    switch (this) {
      case GroupByOption.episode:
        return Icons.list;
      case GroupByOption.series:
        return Icons.folder;
    }
  }
}

enum ContentTypeFilter {
  all,
  movie,
  series;

  String get label {
    switch (this) {
      case ContentTypeFilter.all:
        return 'All';
      case ContentTypeFilter.movie:
        return 'Movies';
      case ContentTypeFilter.series:
        return 'TV Series';
    }
  }

  IconData get icon {
    switch (this) {
      case ContentTypeFilter.all:
        return Icons.grid_view;
      case ContentTypeFilter.movie:
        return Icons.movie;
      case ContentTypeFilter.series:
        return Icons.tv;
    }
  }
}

class WatchHistoryFilterBar extends ConsumerStatefulWidget {
  const WatchHistoryFilterBar({
    required this.searchQuery,
    required this.sortOption,
    required this.sortAscending,
    required this.groupByOption,
    required this.serverFilter,
    required this.contentTypeFilter,
    required this.availableServers,
    required this.onSearchChanged,
    required this.onSortChanged,
    required this.onSortDirectionChanged,
    required this.onGroupByChanged,
    required this.onServerFilterChanged,
    required this.onContentTypeFilterChanged,
    super.key,
  });

  final String searchQuery;
  final SortOption sortOption;
  final bool sortAscending;
  final GroupByOption groupByOption;
  final String? serverFilter;
  final ContentTypeFilter contentTypeFilter;
  final List<String> availableServers;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<SortOption> onSortChanged;
  final VoidCallback onSortDirectionChanged;
  final ValueChanged<GroupByOption> onGroupByChanged;
  final ValueChanged<String?> onServerFilterChanged;
  final ValueChanged<ContentTypeFilter> onContentTypeFilterChanged;

  @override
  ConsumerState<WatchHistoryFilterBar> createState() =>
      _WatchHistoryFilterBarState();
}

class _WatchHistoryFilterBarState extends ConsumerState<WatchHistoryFilterBar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.searchQuery;
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(WatchHistoryFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery &&
        widget.searchQuery != _searchController.text) {
      _searchController.text = widget.searchQuery;
    }
  }

  void _toggleExpanded() async {
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled && vibrationSettings.vibrateOnWatchHistory) {
      await VibrationHelper.vibrate(vibrationSettings.strength);
    }
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
        _searchFocusNode.unfocus();
      }
    });
  }

  bool get _hasActiveFilters =>
      widget.searchQuery.isNotEmpty ||
      widget.sortOption != SortOption.lastWatched ||
      widget.groupByOption != GroupByOption.episode ||
      widget.serverFilter != null ||
      widget.contentTypeFilter != ContentTypeFilter.all;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.outline, width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCollapsedBar(),
          SizeTransition(
            sizeFactor: _expandAnimation,
            child: _buildExpandedContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _toggleExpanded,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasActiveFilters
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.outline,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.tune,
                      size: 18,
                      color: _hasActiveFilters
                          ? AppColors.primary
                          : AppColors.textMid,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _buildFilterSummary(),
                        style: TextStyle(
                          color: _hasActiveFilters
                              ? AppColors.textHigh
                              : AppColors.textMid,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 20,
                        color: AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _clearAllFilters,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.clear, size: 18, color: AppColors.danger),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildFilterSummary() {
    final parts = <String>[];

    if (widget.searchQuery.isNotEmpty) {
      parts.add('"${widget.searchQuery}"');
    }

    if (widget.contentTypeFilter != ContentTypeFilter.all) {
      parts.add(widget.contentTypeFilter.label);
    }

    parts.add(widget.groupByOption.label);
    parts.add(widget.sortOption.label);

    if (widget.serverFilter != null) {
      parts.add(widget.serverFilter!);
    }

    return parts.join(' • ');
  }

  void _clearAllFilters() {
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled && vibrationSettings.vibrateOnWatchHistory) {
      VibrationHelper.vibrate(vibrationSettings.strength);
    }
    _searchController.clear();
    widget.onSearchChanged('');
    widget.onSortChanged(SortOption.lastWatched);
    widget.onGroupByChanged(GroupByOption.episode);
    widget.onServerFilterChanged(null);
    widget.onContentTypeFilterChanged(ContentTypeFilter.all);
  }

  Widget _buildExpandedContent() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSearchField(),
          const SizedBox(height: 12),
          _buildContentTypeFilter(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildGroupBySelector()),
              const SizedBox(width: 8),
              Expanded(child: _buildSortSelector()),
            ],
          ),
          if (widget.availableServers.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildServerFilter(),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      onChanged: widget.onSearchChanged,
      style: const TextStyle(color: AppColors.textHigh, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search in this tab...',
        hintStyle: TextStyle(color: AppColors.textLow, fontSize: 14),
        prefixIcon: Icon(Icons.search, color: AppColors.textMid, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  final vibrationSettings = ref.read(vibrationSettingsProvider);
                  if (vibrationSettings.enabled &&
                      vibrationSettings.vibrateOnWatchHistory) {
                    VibrationHelper.vibrate(vibrationSettings.strength);
                  }
                  _searchController.clear();
                  widget.onSearchChanged('');
                },
                child: Icon(Icons.close, color: AppColors.textMid, size: 20),
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildContentTypeFilter() {
    return Row(
      children: ContentTypeFilter.values.map((filter) {
        final isSelected = widget.contentTypeFilter == filter;
        final isLast = filter == ContentTypeFilter.values.last;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: isLast ? 0 : 8),
            child: GestureDetector(
              onTap: () {
                final vibrationSettings = ref.read(vibrationSettingsProvider);
                if (vibrationSettings.enabled &&
                    vibrationSettings.vibrateOnWatchHistory) {
                  VibrationHelper.vibrate(vibrationSettings.strength);
                }
                widget.onContentTypeFilterChanged(filter);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.outline,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      filter.icon,
                      size: 14,
                      color: isSelected ? AppColors.primary : AppColors.textMid,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      filter.label,
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textMid,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGroupBySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Group By',
          style: TextStyle(
            color: AppColors.textLow,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: GroupByOption.values.map((option) {
              final isSelected = widget.groupByOption == option;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    final vibrationSettings = ref.read(
                      vibrationSettingsProvider,
                    );
                    if (vibrationSettings.enabled &&
                        vibrationSettings.vibrateOnWatchHistory) {
                      VibrationHelper.vibrate(vibrationSettings.strength);
                    }
                    widget.onGroupByChanged(option);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 1)
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          option.icon,
                          size: 14,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMid,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          option.label,
                          style: TextStyle(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textMid,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSortSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sort By',
          style: TextStyle(
            color: AppColors.textLow,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            final vibrationSettings = ref.read(vibrationSettingsProvider);
            if (vibrationSettings.enabled &&
                vibrationSettings.vibrateOnWatchHistory) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            _showSortMenu();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Icon(
                  widget.sortOption.icon,
                  size: 14,
                  color: AppColors.textMid,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.sortOption.label,
                    style: TextStyle(color: AppColors.textHigh, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    final vibrationSettings = ref.read(
                      vibrationSettingsProvider,
                    );
                    if (vibrationSettings.enabled &&
                        vibrationSettings.vibrateOnWatchHistory) {
                      VibrationHelper.vibrate(vibrationSettings.strength);
                    }
                    widget.onSortDirectionChanged();
                  },
                  child: Icon(
                    widget.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Sort By',
                  style: TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...SortOption.values.map((option) {
                final isSelected = widget.sortOption == option;
                return ListTile(
                  leading: Icon(
                    option.icon,
                    color: isSelected ? AppColors.primary : AppColors.textMid,
                  ),
                  title: Text(
                    option.label,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textHigh,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () {
                    final vibrationSettings = ref.read(
                      vibrationSettingsProvider,
                    );
                    if (vibrationSettings.enabled &&
                        vibrationSettings.vibrateOnWatchHistory) {
                      VibrationHelper.vibrate(vibrationSettings.strength);
                    }
                    widget.onSortChanged(option);
                    Navigator.pop(context);
                  },
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServerFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Server',
          style: TextStyle(
            color: AppColors.textLow,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildServerChip(null, 'All'),
              const SizedBox(width: 8),
              ...widget.availableServers.map((server) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildServerChip(server, server.toUpperCase()),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerChip(String? value, String label) {
    final isSelected = widget.serverFilter == value;
    return GestureDetector(
      onTap: () {
        final vibrationSettings = ref.read(vibrationSettingsProvider);
        if (vibrationSettings.enabled &&
            vibrationSettings.vibrateOnWatchHistory) {
          VibrationHelper.vibrate(vibrationSettings.strength);
        }
        widget.onServerFilterChanged(value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primary : AppColors.textMid,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
