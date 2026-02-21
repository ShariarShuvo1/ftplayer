import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/config/subtitle_settings.dart';
import '../../../../../core/utils/vibration_helper.dart';
import '../../../../../state/settings/vibration_settings_provider.dart';
import 'tabs/audio_tracks_tab.dart';
import 'tabs/playback_speed_tab.dart';
import 'tabs/subtitles_tab.dart';
import 'tabs/video_info_tab.dart';

class MediaMenuBottomSheet extends ConsumerStatefulWidget {
  const MediaMenuBottomSheet({
    required this.player,
    this.selectedSubtitleIndex,
    this.selectedAudioIndex,
    required this.onSubtitleChanged,
    required this.onAudioChanged,
    required this.currentSpeed,
    required this.onSpeedChanged,
    required this.subtitleSettings,
    required this.onSubtitleSettingsChanged,
    required this.isFullscreen,
    super.key,
  });

  final Player player;
  final int? selectedSubtitleIndex;
  final int? selectedAudioIndex;
  final Function(int) onSubtitleChanged;
  final Function(int) onAudioChanged;
  final double currentSpeed;
  final Function(double) onSpeedChanged;
  final SubtitleSettings subtitleSettings;
  final ValueChanged<SubtitleSettings> onSubtitleSettingsChanged;
  final bool isFullscreen;

  @override
  ConsumerState<MediaMenuBottomSheet> createState() =>
      _MediaMenuBottomSheetState();
}

class _MediaMenuBottomSheetState extends ConsumerState<MediaMenuBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: 0);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled && vibrationSettings.vibrateOnTabChange) {
      VibrationHelper.vibrate(vibrationSettings.strength);
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            decoration: const BoxDecoration(
              color: AppColors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
              tabs: const [
                Tab(
                  height: 32,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed, size: 18),
                        SizedBox(width: 8),
                        Text('Speed'),
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
                        Icon(Icons.subtitles, size: 18),
                        SizedBox(width: 8),
                        Text('Subtitles'),
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
                        Icon(Icons.audiotrack, size: 18),
                        SizedBox(width: 8),
                        Text('Audio'),
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
                        Icon(Icons.info_outline, size: 18),
                        SizedBox(width: 8),
                        Text('Info'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: widget.isFullscreen ? 300 : 390,
            child: TabBarView(
              controller: _tabController,
              children: [
                PlaybackSpeedTab(
                  player: widget.player,
                  currentSpeed: widget.currentSpeed,
                  onSpeedChanged: widget.onSpeedChanged,
                ),
                SubtitlesTab(
                  player: widget.player,
                  selectedIndex: widget.selectedSubtitleIndex,
                  onSubtitleChanged: widget.onSubtitleChanged,
                  settings: widget.subtitleSettings,
                  onSettingsChanged: widget.onSubtitleSettingsChanged,
                ),
                AudioTracksTab(
                  player: widget.player,
                  selectedIndex: widget.selectedAudioIndex,
                  onAudioChanged: widget.onAudioChanged,
                ),
                VideoInfoTab(player: widget.player),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
