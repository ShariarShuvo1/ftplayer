import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/config/subtitle_settings.dart';
import '../../../core/utils/vibration_helper.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/right_drawer.dart';
import '../../../core/widgets/search_overlay.dart';
import '../../../state/connectivity/connectivity_provider.dart';
import '../../../state/ftp/working_ftp_servers_provider.dart';
import '../../../state/settings/home_content_settings_provider.dart';
import '../../../state/settings/subtitle_settings_provider.dart';
import '../../../state/settings/vibration_settings_provider.dart';
import '../../../state/settings/video_playback_settings_provider.dart';
import '../../search/presentation/search_result_screen.dart';
import 'widgets/general_settings_tab.dart';
import 'widgets/haptic_feedback_settings_tab.dart';
import 'widgets/permissions_settings_tab.dart';
import 'widgets/subtitle_settings_tab.dart';
import 'widgets/video_controller_settings_tab.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const path = '/settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _showSearch = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() async {
      if (!_tabController.indexIsChanging) {
        final vibrationSettings = ref.read(vibrationSettingsProvider);
        if (vibrationSettings.enabled && vibrationSettings.vibrateOnTabChange) {
          await VibrationHelper.vibrate(vibrationSettings.strength);
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
    if (query.isNotEmpty) {
      setState(() {
        _showSearch = false;
      });
      context.pushReplacement(SearchResultScreen.path, extra: query);
    }
  }

  void _handleSearchClose(String query) {
    setState(() {
      _showSearch = false;
    });
  }

  void _restoreCurrentTabDefaults() {
    final currentTabIndex = _tabController.index;

    if (currentTabIndex == 0) {
      ref
          .read(homeContentSettingsProvider.notifier)
          .updateSettings(HomeContentSettings.defaults);
    } else if (currentTabIndex == 1) {
      ref
          .read(vibrationSettingsProvider.notifier)
          .updateSettings(
            const VibrationSettings(
              enabled: true,
              strength: 0.25,
              vibrateOnTabChange: false,
              vibrateOnAppbar: true,
              vibrateOnMenuNavigation: true,
              vibrateOnDownloadScreen: false,
              vibrateOnWatchHistory: false,
              vibrateOnDownloadButton: true,
              vibrateOnSeasonSection: true,
              vibrateOnPip: false,
              vibrateOnGestures: true,
              vibrateOnVideoController: false,
              vibrateOnDoubleTap: false,
              vibrateOnHoldFastForward: true,
              vibrateOnBottomSheet: true,
              vibrateOnContentDetailsOthers: false,
            ),
          );
    } else if (currentTabIndex == 2) {
      ref
          .read(subtitleSettingsProvider.notifier)
          .updateSettings(SubtitleSettings.defaults);
    } else if (currentTabIndex == 3) {
      ref
          .read(videoPlaybackSettingsProvider.notifier)
          .updateSettings(VideoPlaybackSettings.defaults);
    }
  }

  bool _isCurrentTabAtDefaults(WidgetRef ref, int tabIndex) {
    if (tabIndex == 0) {
      final settings = ref.watch(homeContentSettingsProvider);
      final defaults = HomeContentSettings.defaults;
      return settings.featuredCircleFtp == defaults.featuredCircleFtp &&
          settings.featuredAmaderFtp == defaults.featuredAmaderFtp &&
          settings.featuredDflix == defaults.featuredDflix &&
          settings.trendingCircleFtp == defaults.trendingCircleFtp &&
          settings.trendingAmaderFtp == defaults.trendingAmaderFtp &&
          settings.trendingDflix == defaults.trendingDflix &&
          settings.latestCircleFtp == defaults.latestCircleFtp &&
          settings.latestAmaderFtp == defaults.latestAmaderFtp &&
          settings.latestDflix == defaults.latestDflix &&
          settings.tvSeriesCircleFtp == defaults.tvSeriesCircleFtp &&
          settings.tvSeriesAmaderFtp == defaults.tvSeriesAmaderFtp &&
          settings.tvSeriesDflix == defaults.tvSeriesDflix &&
          settings.pingTimeCircleFtp == defaults.pingTimeCircleFtp &&
          settings.pingTimeAmaderFtp == defaults.pingTimeAmaderFtp &&
          settings.pingTimeDflix == defaults.pingTimeDflix;
    } else if (tabIndex == 1) {
      final settings = ref.watch(vibrationSettingsProvider);
      return settings.enabled == true &&
          settings.strength == 0.25 &&
          settings.vibrateOnTabChange == false &&
          settings.vibrateOnAppbar == true &&
          settings.vibrateOnMenuNavigation == true &&
          settings.vibrateOnDownloadScreen == false &&
          settings.vibrateOnWatchHistory == false &&
          settings.vibrateOnDownloadButton == true &&
          settings.vibrateOnSeasonSection == true &&
          settings.vibrateOnPip == false &&
          settings.vibrateOnGestures == true &&
          settings.vibrateOnVideoController == false &&
          settings.vibrateOnDoubleTap == false &&
          settings.vibrateOnHoldFastForward == true &&
          settings.vibrateOnBottomSheet == true &&
          settings.vibrateOnContentDetailsOthers == false;
    } else if (tabIndex == 2) {
      final settings = ref.watch(subtitleSettingsProvider);
      final defaults = SubtitleSettings.defaults;
      return settings.fontSize == defaults.fontSize &&
          settings.textColor.toARGB32() == defaults.textColor.toARGB32() &&
          settings.backgroundColor.toARGB32() ==
              defaults.backgroundColor.toARGB32() &&
          settings.backgroundOpacity == defaults.backgroundOpacity;
    } else if (tabIndex == 3) {
      final settings = ref.watch(videoPlaybackSettingsProvider);
      final defaults = VideoPlaybackSettings.defaults;
      return settings.holdToSpeedRate == defaults.holdToSpeedRate &&
          settings.autoCompleteThreshold == defaults.autoCompleteThreshold &&
          settings.leftDoubleTapSkipSeconds ==
              defaults.leftDoubleTapSkipSeconds &&
          settings.rightDoubleTapSkipSeconds ==
              defaults.rightDoubleTapSkipSeconds;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(offlineModeProvider);
    final workingServersAsync = ref.watch(workingFtpServersProvider);

    return AppScaffold(
      title: 'Settings',
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
        Consumer(
          builder: (context, ref, child) {
            final currentTabIndex = _tabController.index;
            if (currentTabIndex == 4) {
              return const SizedBox.shrink();
            }
            final isAtDefaults = _isCurrentTabAtDefaults(ref, currentTabIndex);
            return IconButton(
              tooltip: 'Restore to defaults',
              onPressed: isAtDefaults
                  ? null
                  : () {
                      final vibrationSettings = ref.read(
                        vibrationSettingsProvider,
                      );
                      if (vibrationSettings.enabled &&
                          vibrationSettings.vibrateOnAppbar) {
                        VibrationHelper.vibrate(vibrationSettings.strength);
                      }
                      _restoreCurrentTabDefaults();
                    },
              icon: const Icon(Icons.restore),
              color: isAtDefaults ? AppColors.textLow : AppColors.primary,
            );
          },
        ),
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
                  tabs: const [
                    Tab(
                      height: 32,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.settings_outlined, size: 16),
                            SizedBox(width: 6),
                            Text('General'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      height: 32,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.vibration, size: 16),
                            SizedBox(width: 6),
                            Text('Haptic'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      height: 32,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.subtitles, size: 16),
                            SizedBox(width: 6),
                            Text('Subtitle'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      height: 32,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_outline, size: 16),
                            SizedBox(width: 6),
                            Text('Video'),
                          ],
                        ),
                      ),
                    ),
                    Tab(
                      height: 32,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.security, size: 16),
                            SizedBox(width: 6),
                            Text('Permissions'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    GeneralSettingsTab(),
                    HapticFeedbackSettingsTab(),
                    SubtitleSettingsTab(),
                    VideoControllerSettingsTab(),
                    PermissionsSettingsTab(),
                  ],
                ),
              ),
            ],
          ),
          if (_showSearch)
            Positioned.fill(
              child: SearchOverlay(
                onSearch: _handleSearch,
                onClose: _handleSearchClose,
              ),
            ),
        ],
      ),
    );
  }
}
