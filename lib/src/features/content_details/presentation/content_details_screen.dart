import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:logger/logger.dart';
import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_snackbars.dart';
import '../../../core/utils/vibration_helper.dart';
import '../../../state/content/content_details_provider.dart';
import '../../../state/settings/vibration_settings_provider.dart';
import '../../../state/content/current_playing_content_provider.dart';
import '../../../state/content/playback_state_provider.dart';
import '../../../state/pip/pip_provider.dart';
import '../../../state/pip/pip_state.dart';
import '../../../state/ftp/working_ftp_servers_provider.dart';
import '../../../state/watch_history/watch_history_provider.dart';
import '../../../state/connectivity/connectivity_provider.dart';
import '../../../state/downloads/download_provider.dart';
import '../../../state/settings/video_playback_settings_provider.dart';
import '../../watch_history/data/watch_history_storage.dart';
import '../../ftp_servers/data/ftp_servers_local_data.dart';
import '../../home/data/home_models.dart';
import '../data/content_details_models.dart';
import '../../watch_history/data/watch_history_models.dart';
import 'widgets/video_player/video_player_widget.dart';
import 'widgets/content_info/watch_status_dropdown.dart';
import 'widgets/content_info/content_details_section.dart';
import 'widgets/seasons/seasons_section.dart';
import 'widgets/content_info/download_button.dart';

class ContentDetailsScreen extends ConsumerStatefulWidget {
  const ContentDetailsScreen({required this.contentItem, super.key});

  static const path = '/content-details';

  final ContentItem contentItem;

  @override
  ConsumerState<ContentDetailsScreen> createState() =>
      _ContentDetailsScreenState();
}

class _ContentDetailsScreenState extends ConsumerState<ContentDetailsScreen>
    with TickerProviderStateMixin {
  final Logger _logger = Logger();

  TabController? _tabController;
  String? _currentVideoUrl;
  int? _currentSeasonNumber;
  int? _currentEpisodeNumber;
  String? _currentEpisodeId;
  String? _currentEpisodeTitle;
  double _dragOffset = 0.0;
  double _dragHorizontalPosition = 0.0;
  bool _isDragging = false;
  bool _activatedPipFromHere = false;
  Player? _receivedPlayer;
  VideoController? _receivedVideoController;
  bool _isVideoPlayerFullscreen = false;
  Duration? _initialPosition;

  int _playbackGeneration = 0;

  List<SeasonProgress>? _liveSeriesProgress;
  int _progressUpdateCounter = 0;
  DateTime? _lastProgressUpdate;
  bool _nextUpdateIsImmediate = false;
  bool _hasTriggeredAutoComplete = false;
  GlobalKey<_VideoPlayerWidgetWrapperState> _videoPlayerKey = GlobalKey();
  AnimationController? _pipTransitionController;
  final double _pipTriggerFraction = 0.4;
  final double _sectionHideFraction = 0.2;

  double _getSwipeProgress(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return (_dragOffset / (screenHeight * _pipTriggerFraction)).clamp(0.0, 1.0);
  }

  double _getSectionHideProgress(BuildContext context) {
    return (_getSwipeProgress(context) / _sectionHideFraction).clamp(0.0, 1.0);
  }

  double _getVideoScaleProgress(BuildContext context) {
    const pipHeight = 100.0;
    final videoPlayerHeight = 250.0;

    final targetScale = (pipHeight / videoPlayerHeight);
    return 1.0 - ((_getSwipeProgress(context) * (1.0 - targetScale)));
  }

  double _getVideoCornerRadiusProgress(BuildContext context) {
    return _getSwipeProgress(context);
  }

  double _getVideoHorizontalOffset(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = _getSwipeProgress(context);
    const pipWidth = 180.0;

    final snapToLeft = _dragHorizontalPosition < screenWidth / 2;
    final targetOffset = snapToLeft
        ? 16.0 - (screenWidth / 2 - pipWidth / 2)
        : (screenWidth - pipWidth - 16.0) - (screenWidth / 2 - pipWidth / 2);

    return targetOffset * progress;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeWatchHistory();
    });

    if (widget.contentItem.initialProgress != null) {
      _initialPosition = widget.contentItem.initialProgress;
    }

    if (widget.contentItem.initialData != null) {
      try {
        ContentDetails.fromMetadata(widget.contentItem.initialData!);
      } catch (e) {
        _logger.e('Failed to parse offline metadata during init: $e', error: e);
      }
    }

    final pipState = ref.read(pipProvider);
    if (!_activatedPipFromHere &&
        pipState.isActive &&
        pipState.player != null &&
        pipState.videoController != null &&
        pipState.contentItemJson != null) {
      try {
        final pipContentItem = ContentItem.fromJson(pipState.contentItemJson!);
        if (pipContentItem.id == widget.contentItem.id) {
          _receivedPlayer = pipState.player;
          _receivedVideoController = pipState.videoController;

          _currentVideoUrl = pipState.currentVideoUrl;
          _currentSeasonNumber = pipState.currentSeasonNumber;
          _currentEpisodeNumber = pipState.currentEpisodeNumber;
          _currentEpisodeId = pipState.currentEpisodeId;
          _currentEpisodeTitle = pipState.currentEpisodeTitle;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _animatePipToVideoPlayer(pipState);
          });

          Future.microtask(() {
            ref
                .read(currentPlayingContentProvider.notifier)
                .state = CurrentPlayingContent(
              contentId: widget.contentItem.id,
              seasonNumber: _currentSeasonNumber,
              episodeNumber: _currentEpisodeNumber,
            );
            ref.read(playbackStateProvider.notifier).clearPlaybackState();
          });
          return;
        } else {
          Future.microtask(() {
            ref.read(pipProvider.notifier).deactivatePip(disposePlayer: true);
          });
        }
      } catch (e) {
        _logger.e('[Playback] Error processing PIP state: $e', error: e);
      }
    }

    final hasExplicitInitialEpisode =
        widget.contentItem.initialSeasonNumber != null ||
        widget.contentItem.initialEpisodeNumber != null ||
        widget.contentItem.initialEpisodeId != null;

    final playbackCache = ref
        .read(playbackStateProvider.notifier)
        .getPlaybackStateIfValid(widget.contentItem.id);

    if (!hasExplicitInitialEpisode && playbackCache != null) {
      _receivedPlayer = playbackCache.player;
      _receivedVideoController = playbackCache.videoController;
      _currentVideoUrl = playbackCache.currentVideoUrl;
      _currentSeasonNumber = playbackCache.currentSeasonNumber;
      _currentEpisodeNumber = playbackCache.currentEpisodeNumber;
      _currentEpisodeId = playbackCache.currentEpisodeId;
      _currentEpisodeTitle = playbackCache.currentEpisodeTitle;
      if (playbackCache.currentPosition != null) {
        _initialPosition = playbackCache.currentPosition;
      }

      Future.microtask(() {
        ref
            .read(currentPlayingContentProvider.notifier)
            .state = CurrentPlayingContent(
          contentId: widget.contentItem.id,
          seasonNumber: _currentSeasonNumber,
          episodeNumber: _currentEpisodeNumber,
        );
        ref.read(playbackStateProvider.notifier).clearPlaybackState();
      });
      return;
    }
  }

  void _notifyPlayerReceived() {
    if (_receivedPlayer != null && _receivedVideoController != null) {
      final videoPlayerState = _videoPlayerKey.currentState;
      if (videoPlayerState != null) {
        videoPlayerState.receiveOwnership(
          _receivedPlayer!,
          _receivedVideoController!,
        );
        _receivedPlayer = null;
        _receivedVideoController = null;
      }
    }
  }

  Future<void> _initializeWatchHistory() async {
    try {
      final server = FtpServersLocalData.getServerByName(
        widget.contentItem.serverName,
      );

      if (server == null) {
        return;
      }

      final storage = ref.read(watchHistoryStorageProvider);
      final existing = await storage.getWatchHistory(
        ftpServerId: server.id,
        contentId: widget.contentItem.id,
      );

      if (existing == null) {
        String posterUrl = widget.contentItem.posterUrl;
        final isOffline = ref.read(offlineModeProvider);

        if (isOffline) {
          final downloadedContent = ref.read(
            downloadedContentItemProvider((
              contentId: widget.contentItem.id,
              seasonNumber: widget.contentItem.initialSeasonNumber,
              episodeNumber: widget.contentItem.initialEpisodeNumber,
            )),
          );

          if (downloadedContent != null &&
              downloadedContent.localPosterPath != null &&
              downloadedContent.localPosterPath!.isNotEmpty) {
            posterUrl = downloadedContent.localPosterPath!;
          }
        }

        await ref
            .read(watchHistoryNotifierProvider.notifier)
            .updateStatus(
              ftpServerId: server.id,
              serverName: server.name,
              serverType: widget.contentItem.serverType,
              contentType: widget.contentItem.contentType ?? 'movie',
              contentId: widget.contentItem.id,
              contentTitle: widget.contentItem.title,
              status: WatchStatus.watching,
              metadata: {'posterUrl': posterUrl},
            );
      }
    } catch (e) {
      _logger.e('Failed to initialize watch history: $e', error: e);
    }
  }

  Future<void> _selectInitialEpisode(ContentDetails details) async {
    if (_currentVideoUrl != null ||
        !details.isSeries ||
        details.seasons == null ||
        details.seasons!.isEmpty) {
      if (!details.isSeries) {
        ref
            .read(currentPlayingContentProvider.notifier)
            .state = CurrentPlayingContent(
          contentId: widget.contentItem.id,
          seasonNumber: null,
          episodeNumber: null,
        );
      }
      return;
    }

    if (widget.contentItem.initialSeasonNumber != null &&
        widget.contentItem.initialEpisodeNumber != null) {
      final season = details.seasons!.firstWhere((s) {
        final seasonNum = _extractSeasonNumber(s.seasonName);
        return seasonNum == widget.contentItem.initialSeasonNumber;
      }, orElse: () => details.seasons!.first);

      if (season.episodes.isNotEmpty) {
        final episode =
            season.episodes[(widget.contentItem.initialEpisodeNumber! - 1)
                .clamp(0, season.episodes.length - 1)];

        final isOffline = ref.read(offlineModeProvider);
        String resolvedUrl = episode.link;

        if (isOffline) {
          final downloadedContent = ref.read(
            downloadedContentItemProvider((
              contentId: widget.contentItem.id,
              seasonNumber: widget.contentItem.initialSeasonNumber!,
              episodeNumber: widget.contentItem.initialEpisodeNumber!,
            )),
          );
          if (downloadedContent != null &&
              downloadedContent.localPath.isNotEmpty) {
            resolvedUrl = downloadedContent.localPath;
          }
        }

        setState(() {
          _currentVideoUrl = resolvedUrl;
          _currentSeasonNumber = widget.contentItem.initialSeasonNumber;
          _currentEpisodeNumber = widget.contentItem.initialEpisodeNumber;
          _currentEpisodeId = widget.contentItem.initialEpisodeId;
          _currentEpisodeTitle = episode.title;
        });

        ref
            .read(currentPlayingContentProvider.notifier)
            .state = CurrentPlayingContent(
          contentId: widget.contentItem.id,
          seasonNumber: widget.contentItem.initialSeasonNumber!,
          episodeNumber: widget.contentItem.initialEpisodeNumber!,
        );
      }
      return;
    }

    final serverId = _resolveCurrentServerId();
    if (serverId != null) {
      try {
        final watchHistory = await ref.read(
          contentWatchHistoryProvider((
            ftpServerId: serverId,
            contentId: widget.contentItem.id,
          )).future,
        );

        if (watchHistory?.seriesProgress != null &&
            watchHistory!.seriesProgress!.isNotEmpty) {
          EpisodeProgress? lastWatchedEpisode;
          int? lastWatchedSeasonNumber;

          for (final seasonProgress in watchHistory.seriesProgress!) {
            for (final episodeProgress in seasonProgress.episodes) {
              if (lastWatchedEpisode == null ||
                  episodeProgress.lastWatchedAt.isAfter(
                    lastWatchedEpisode.lastWatchedAt,
                  )) {
                lastWatchedEpisode = episodeProgress;
                lastWatchedSeasonNumber = seasonProgress.seasonNumber;
              }
            }
          }

          if (lastWatchedEpisode != null && lastWatchedSeasonNumber != null) {
            final season = details.seasons!.firstWhere(
              (s) =>
                  _extractSeasonNumber(s.seasonName) == lastWatchedSeasonNumber,
              orElse: () => details.seasons!.first,
            );

            final episodeIndex = lastWatchedEpisode.episodeNumber - 1;
            if (episodeIndex >= 0 && episodeIndex < season.episodes.length) {
              final episode = season.episodes[episodeIndex];
              final isOffline = ref.read(offlineModeProvider);
              String resolvedUrl = episode.link;

              if (isOffline) {
                final downloadedContent = ref.read(
                  downloadedContentItemProvider((
                    contentId: widget.contentItem.id,
                    seasonNumber: lastWatchedSeasonNumber,
                    episodeNumber: lastWatchedEpisode.episodeNumber,
                  )),
                );
                if (downloadedContent != null &&
                    downloadedContent.localPath.isNotEmpty) {
                  resolvedUrl = downloadedContent.localPath;
                }
              }

              final progress = lastWatchedEpisode.progress;
              if (progress.currentTime > 0 && progress.duration > 0) {
                final percentage =
                    (progress.currentTime / progress.duration) * 100;
                if (percentage < 95) {
                  _initialPosition = Duration(
                    seconds: progress.currentTime.toInt(),
                  );
                }
              }

              setState(() {
                _currentVideoUrl = resolvedUrl;
                _currentSeasonNumber = lastWatchedSeasonNumber;
                _currentEpisodeNumber = lastWatchedEpisode!.episodeNumber;
                _currentEpisodeId = lastWatchedEpisode.episodeId;
                _currentEpisodeTitle = episode.title;
              });

              _updateTabControllerToSeason(details, lastWatchedSeasonNumber);

              ref
                  .read(currentPlayingContentProvider.notifier)
                  .state = CurrentPlayingContent(
                contentId: widget.contentItem.id,
                seasonNumber: lastWatchedSeasonNumber,
                episodeNumber: lastWatchedEpisode.episodeNumber,
              );
              return;
            }
          }
        }
      } catch (e) {
        _logger.e('Error fetching watch history for auto-play: $e');
      }
    }

    final firstSeason = details.seasons!.first;
    if (firstSeason.episodes.isNotEmpty) {
      final firstEpisode = firstSeason.episodes.first;
      final firstSeasonNumber = _extractSeasonNumber(firstSeason.seasonName);
      final isOffline = ref.read(offlineModeProvider);
      String resolvedUrl = firstEpisode.link;

      if (isOffline) {
        final downloadedContent = ref.read(
          downloadedContentItemProvider((
            contentId: widget.contentItem.id,
            seasonNumber: firstSeasonNumber,
            episodeNumber: 1,
          )),
        );
        if (downloadedContent != null &&
            downloadedContent.localPath.isNotEmpty) {
          resolvedUrl = downloadedContent.localPath;
        }
      }

      setState(() {
        _currentVideoUrl = resolvedUrl;
        _currentSeasonNumber = firstSeasonNumber;
        _currentEpisodeNumber = firstEpisode.episodeNumber ?? 1;
        _currentEpisodeId = firstEpisode.id;
        _currentEpisodeTitle = firstEpisode.title;
      });

      ref
          .read(currentPlayingContentProvider.notifier)
          .state = CurrentPlayingContent(
        contentId: widget.contentItem.id,
        seasonNumber: firstSeasonNumber,
        episodeNumber: firstEpisode.episodeNumber ?? 1,
      );
    }
  }

  int _extractSeasonNumber(String seasonName) {
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(seasonName);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  Future<Duration?> _fetchInitialPositionForEpisode(
    String serverId,
    int seasonNumber,
    int episodeNumber,
  ) async {
    try {
      final watchHistoryAsync = await ref.refresh(
        contentWatchHistoryProvider((
          ftpServerId: serverId,
          contentId: widget.contentItem.id,
        )).future,
      );

      if (watchHistoryAsync?.seriesProgress != null) {
        final season = watchHistoryAsync!.seriesProgress!
            .where((s) => s.seasonNumber == seasonNumber)
            .firstOrNull;

        if (season == null) {
          return Duration.zero;
        }

        final episode = season.episodes
            .where((e) => e.episodeNumber == episodeNumber)
            .firstOrNull;

        if (episode == null) {
          return Duration.zero;
        }

        if (episode.progress.currentTime > 0 && episode.progress.duration > 0) {
          final currentTime = episode.progress.currentTime;
          final duration = episode.progress.duration;
          final percentage = (currentTime / duration) * 100;
          if (percentage >= 95) {
            return Duration.zero;
          } else if (currentTime > 0) {
            final position = Duration(seconds: currentTime.toInt());
            return position;
          }
        }
      }

      return Duration.zero;
    } catch (e) {
      _logger.e(
        'Error fetching watch history for S${seasonNumber}E$episodeNumber: $e',
      );
      return Duration.zero;
    }
  }

  String _resolveVideoUrl(WidgetRef ref, String originalUrl) {
    final downloadedContent = ref.read(
      downloadedContentItemProvider((
        contentId: widget.contentItem.id,
        seasonNumber: _currentSeasonNumber,
        episodeNumber: _currentEpisodeNumber,
      )),
    );

    if (downloadedContent != null && downloadedContent.localPath.isNotEmpty) {
      return downloadedContent.localPath;
    }

    return originalUrl;
  }

  String? _resolveCurrentServerId() {
    final server = FtpServersLocalData.getServerByName(
      widget.contentItem.serverName,
    );
    if (server != null) {
      return server.id;
    }

    final workingServersAsync = ref.read(workingFtpServersProvider);

    if (!workingServersAsync.hasValue) {
      return null;
    }

    final servers = workingServersAsync.value!;
    final workingServer = servers
        .where((s) => s.name == widget.contentItem.serverName)
        .firstOrNull;

    return workingServer?.id;
  }

  int _resolveSeasonNumber(Season season, int index) {
    final number =
        season.seasonNumber ?? _extractSeasonNumber(season.seasonName);
    if (number > 0) {
      return number;
    }
    return index + 1;
  }

  int _resolveEpisodeNumber(Episode episode, int index) {
    return index + 1;
  }

  int _findSeasonIndex(List<Season> seasons, int seasonNumber) {
    for (int i = 0; i < seasons.length; i++) {
      if (_resolveSeasonNumber(seasons[i], i) == seasonNumber) {
        return i;
      }
    }
    return -1;
  }

  int _findEpisodeIndex(List<Episode> episodes, int episodeNumber) {
    final index = episodeNumber - 1;
    if (index >= 0 && index < episodes.length) {
      return index;
    }
    return -1;
  }

  _EpisodeNavTarget? _findPreviousEpisodeTarget(ContentDetails details) {
    if (!details.isSeries ||
        details.seasons == null ||
        details.seasons!.isEmpty ||
        _currentSeasonNumber == null ||
        _currentEpisodeNumber == null) {
      return null;
    }

    final seasons = details.seasons!;
    final currentSeasonIndex = _findSeasonIndex(seasons, _currentSeasonNumber!);
    if (currentSeasonIndex == -1) {
      return null;
    }

    final currentSeason = seasons[currentSeasonIndex];
    if (currentSeason.episodes.isEmpty) {
      return null;
    }

    final currentEpisodeIndex = _findEpisodeIndex(
      currentSeason.episodes,
      _currentEpisodeNumber!,
    );

    if (currentEpisodeIndex == -1) {
      return null;
    }

    if (currentEpisodeIndex > 0) {
      final targetEpisode = currentSeason.episodes[currentEpisodeIndex - 1];
      final seasonNumber = _resolveSeasonNumber(
        currentSeason,
        currentSeasonIndex,
      );
      final episodeNumber = _resolveEpisodeNumber(
        targetEpisode,
        currentEpisodeIndex - 1,
      );
      return _EpisodeNavTarget(
        season: currentSeason,
        seasonNumber: seasonNumber,
        episode: targetEpisode,
        episodeNumber: episodeNumber,
      );
    }

    for (int i = currentSeasonIndex - 1; i >= 0; i--) {
      final previousSeason = seasons[i];
      if (previousSeason.episodes.isEmpty) {
        continue;
      }
      final seasonNumber = _resolveSeasonNumber(previousSeason, i);
      final episodeIndex = previousSeason.episodes.length - 1;
      final episode = previousSeason.episodes[episodeIndex];
      final episodeNumber = _resolveEpisodeNumber(episode, episodeIndex);

      return _EpisodeNavTarget(
        season: previousSeason,
        seasonNumber: seasonNumber,
        episode: episode,
        episodeNumber: episodeNumber,
      );
    }

    return null;
  }

  _EpisodeNavTarget? _findNextEpisodeTarget(ContentDetails details) {
    if (!details.isSeries ||
        details.seasons == null ||
        details.seasons!.isEmpty ||
        _currentSeasonNumber == null ||
        _currentEpisodeNumber == null) {
      return null;
    }

    final seasons = details.seasons!;
    final currentSeasonIndex = _findSeasonIndex(seasons, _currentSeasonNumber!);
    if (currentSeasonIndex == -1) {
      return null;
    }

    final currentSeason = seasons[currentSeasonIndex];
    if (currentSeason.episodes.isEmpty) {
      return null;
    }

    final currentEpisodeIndex = _findEpisodeIndex(
      currentSeason.episodes,
      _currentEpisodeNumber!,
    );

    if (currentEpisodeIndex == -1) {
      return null;
    }

    if (currentEpisodeIndex < currentSeason.episodes.length - 1) {
      final targetEpisode = currentSeason.episodes[currentEpisodeIndex + 1];
      final seasonNumber = _resolveSeasonNumber(
        currentSeason,
        currentSeasonIndex,
      );
      final episodeNumber = _resolveEpisodeNumber(
        targetEpisode,
        currentEpisodeIndex + 1,
      );
      return _EpisodeNavTarget(
        season: currentSeason,
        seasonNumber: seasonNumber,
        episode: targetEpisode,
        episodeNumber: episodeNumber,
      );
    }

    return null;
  }

  _EpisodeNavigationConfig _buildEpisodeNavigationConfig(
    ContentDetails details,
  ) {
    final showControls =
        details.isSeries &&
        details.seasons != null &&
        details.seasons!.isNotEmpty;

    if (!showControls) {
      return const _EpisodeNavigationConfig(
        showEpisodeControls: false,
        canGoToPreviousEpisode: false,
        canGoToNextEpisode: false,
        onPreviousEpisode: null,
        onNextEpisode: null,
      );
    }

    final previousTarget = _findPreviousEpisodeTarget(details);
    final nextTarget = _findNextEpisodeTarget(details);

    return _EpisodeNavigationConfig(
      showEpisodeControls: true,
      canGoToPreviousEpisode: previousTarget != null,
      canGoToNextEpisode: nextTarget != null,
      onPreviousEpisode: previousTarget == null
          ? null
          : () => _handleEpisodeTap(
              previousTarget.season,
              previousTarget.seasonNumber,
              previousTarget.episodeNumber,
              previousTarget.episode,
            ),
      onNextEpisode: nextTarget == null
          ? null
          : () => _handleEpisodeTap(
              nextTarget.season,
              nextTarget.seasonNumber,
              nextTarget.episodeNumber,
              nextTarget.episode,
            ),
    );
  }

  void _updateTabControllerToSeason(ContentDetails details, int seasonNumber) {
    if (details.seasons == null || _tabController == null) return;

    final seasonIndex = details.seasons!.indexWhere((season) {
      final seasonNum = _extractSeasonNumber(season.seasonName);
      return seasonNum == seasonNumber;
    });

    if (seasonIndex >= 0 && _tabController!.index != seasonIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _tabController != null) {
          _tabController!.animateTo(seasonIndex);
        }
      });
    }
  }

  @override
  void deactivate() {
    try {
      final pipState = ref.read(pipProvider);
      final videoPlayerState = _videoPlayerKey.currentState;
      final playbackNotifier = ref.read(playbackStateProvider.notifier);

      if (videoPlayerState != null &&
          videoPlayerState.player != null &&
          videoPlayerState.videoController != null &&
          !(_activatedPipFromHere && pipState.isActive)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            playbackNotifier.cachePlaybackState(
              contentId: widget.contentItem.id,
              player: videoPlayerState.player,
              videoController: videoPlayerState.videoController,
              currentVideoUrl: _currentVideoUrl,
              currentSeasonNumber: _currentSeasonNumber,
              currentEpisodeNumber: _currentEpisodeNumber,
              currentEpisodeId: _currentEpisodeId,
              currentEpisodeTitle: _currentEpisodeTitle,
              currentPosition: videoPlayerState.currentPosition,
            );
          } catch (e) {
            _logger.e('[Playback] Error in post-frame cache: $e', error: e);
          }
        });
      }
    } catch (e) {
      _logger.e('[Playback] Error caching playback state: $e', error: e);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _pipTransitionController?.dispose();
    super.dispose();
  }

  Future<void> _animatePipToVideoPlayer(PipState pipState) async {
    if (!mounted) return;

    ref.read(pipProvider.notifier).deactivatePip(disposePlayer: false);

    await Future.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    final targetWidth = size.width;
    final targetHeight = 250.0;

    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    _pipTransitionController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    final positionAnimation =
        Tween<Offset>(
          begin: pipState.position,
          end: const Offset(0, 0),
        ).animate(
          CurvedAnimation(
            parent: _pipTransitionController!,
            curve: Curves.easeInOutCubic,
          ),
        );

    final widthAnimation =
        Tween<double>(begin: pipState.width, end: targetWidth).animate(
          CurvedAnimation(
            parent: _pipTransitionController!,
            curve: Curves.easeInOutCubic,
          ),
        );

    final heightAnimation =
        Tween<double>(begin: pipState.height, end: targetHeight).animate(
          CurvedAnimation(
            parent: _pipTransitionController!,
            curve: Curves.easeInOutCubic,
          ),
        );

    overlayEntry = OverlayEntry(
      builder: (context) => AnimatedBuilder(
        animation: _pipTransitionController!,
        builder: (context, child) {
          return Positioned(
            left: positionAnimation.value.dx,
            top: positionAnimation.value.dy,
            child: Container(
              width: widthAnimation.value,
              height: heightAnimation.value,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(
                  12 * (1 - _pipTransitionController!.value),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  12 * (1 - _pipTransitionController!.value),
                ),
                child: Video(
                  controller: pipState.videoController!,
                  controls: NoVideoControls,
                ),
              ),
            ),
          );
        },
      ),
    );

    overlay.insert(overlayEntry);

    await _pipTransitionController!.forward();

    overlayEntry.remove();
    overlayEntry.dispose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (_isVideoPlayerFullscreen) return;
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dy;
      _dragHorizontalPosition = details.globalPosition.dx;
      _dragOffset = _dragOffset.clamp(0.0, double.infinity);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isVideoPlayerFullscreen) return;
    final threshold = MediaQuery.of(context).size.height * _pipTriggerFraction;

    if (_dragOffset > threshold) {
      _activatePipMode();
    } else {
      setState(() {
        _dragOffset = 0.0;
        _isDragging = false;
      });
    }
  }

  void _activatePipMode() async {
    if (_activatedPipFromHere) {
      return;
    }

    final videoPlayerState = _videoPlayerKey.currentState;

    if (videoPlayerState == null) {
      _resetDragState();
      return;
    }

    if (videoPlayerState.player == null ||
        videoPlayerState.videoController == null) {
      _resetDragState();
      return;
    }

    try {
      final title = widget.contentItem.title;

      String videoUrl = _currentVideoUrl ?? '';

      if (videoUrl.isEmpty) {
        _resetDragState();
        return;
      }

      final screenWidth = MediaQuery.of(context).size.width;
      const pipWidth = 180.0;
      final snapToLeft = _dragHorizontalPosition < screenWidth / 2;
      final initialPosition = Offset(
        snapToLeft ? 16 : screenWidth - pipWidth - 16,
        _dragOffset.clamp(0, MediaQuery.of(context).size.height - 100),
      );

      _nextUpdateIsImmediate = true;
      if (videoPlayerState.player != null) {
        final currentTime = videoPlayerState.player!.state.position.inSeconds
            .toDouble();
        final duration = videoPlayerState.player!.state.duration.inSeconds
            .toDouble();
        if (duration > 0) {
          final detailsAsync = ref.read(
            contentDetailsProvider((
              contentId: widget.contentItem.id,
              serverName: widget.contentItem.serverName,
              serverType: widget.contentItem.serverType,
              initialData: widget.contentItem.initialData,
            )),
          );
          detailsAsync.whenData((details) {
            final server = FtpServersLocalData.getServerByName(
              widget.contentItem.serverName,
            );
            if (server != null) {
              _handleProgressUpdate(
                details,
                server.id,
                widget.contentItem.serverName,
                currentTime,
                duration,
                immediate: true,
              );
            }
          });
        }
      }

      try {
        final storage = ref.read(watchHistoryStorageProvider);
        await storage.flush();
      } catch (e) {
        _logger.e('[PIP Activate] Error flushing watch history: $e');
      }

      ref
          .read(pipProvider.notifier)
          .activatePip(
            player: videoPlayerState.player!,
            videoController: videoPlayerState.videoController!,
            videoUrl: videoUrl,
            videoTitle: title,
            contentItemJson: widget.contentItem.toJson(),
            initialPosition: initialPosition,
            currentVideoUrl: _currentVideoUrl,
            currentSeasonNumber: _currentSeasonNumber,
            currentEpisodeNumber: _currentEpisodeNumber,
            currentEpisodeId: _currentEpisodeId,
            currentEpisodeTitle: _currentEpisodeTitle,
          );

      final vibrationSettings = ref.read(vibrationSettingsProvider);
      if (vibrationSettings.enabled && vibrationSettings.vibrateOnPip) {
        VibrationHelper.vibrate(vibrationSettings.strength);
      }

      videoPlayerState.transferOwnership();

      setState(() {
        _activatedPipFromHere = true;
      });

      if (videoPlayerState.player != null) {
        try {
          await videoPlayerState.player!.play();
        } catch (e) {
          _logger.e('Error playing video in PIP mode: $e');
        }
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _logger.e('[_activatePipMode] Error: $e');
      _resetDragState();
    }
  }

  void _resetDragState() {
    setState(() {
      _dragOffset = 0.0;
      _isDragging = false;
    });
  }

  ({
    int seasonNumber,
    int episodeNumber,
    String? episodeId,
    String episodeTitle,
  })?
  _findFirstDownloadedEpisode(ContentDetails details) {
    if (details.seasons == null || details.seasons!.isEmpty) {
      return null;
    }

    for (
      int seasonIndex = 0;
      seasonIndex < details.seasons!.length;
      seasonIndex++
    ) {
      final season = details.seasons![seasonIndex];
      final seasonNumber = _extractSeasonNumber(season.seasonName);

      for (
        int episodeIndex = 0;
        episodeIndex < season.episodes.length;
        episodeIndex++
      ) {
        final episode = season.episodes[episodeIndex];
        final episodeNumber = episode.episodeNumber ?? (episodeIndex + 1);

        final downloadedContent = ref.read(
          downloadedContentItemProvider((
            contentId: widget.contentItem.id,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
          )),
        );

        if (downloadedContent != null &&
            downloadedContent.localPath.isNotEmpty) {
          return (
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
            episodeId: episode.id,
            episodeTitle: episode.title,
          );
        }
      }
    }

    return null;
  }

  ContentDetails _resolveOfflineEpisodeLinks(ContentDetails details) {
    if (details.seasons == null || details.seasons!.isEmpty) {
      return details;
    }

    final updatedSeasons = <Season>[];

    for (
      int seasonIndex = 0;
      seasonIndex < details.seasons!.length;
      seasonIndex++
    ) {
      final season = details.seasons![seasonIndex];
      final seasonNumber = _extractSeasonNumber(season.seasonName);
      final updatedEpisodes = <Episode>[];

      for (
        int episodeIndex = 0;
        episodeIndex < season.episodes.length;
        episodeIndex++
      ) {
        final episode = season.episodes[episodeIndex];
        final episodeNumber = episode.episodeNumber ?? (episodeIndex + 1);

        String resolvedLink = episode.link;
        final downloadedContent = ref.read(
          downloadedContentItemProvider((
            contentId: widget.contentItem.id,
            seasonNumber: seasonNumber,
            episodeNumber: episodeNumber,
          )),
        );

        if (downloadedContent != null &&
            downloadedContent.localPath.isNotEmpty) {
          resolvedLink = downloadedContent.localPath;
        }

        updatedEpisodes.add(
          Episode(
            title: episode.title,
            link: resolvedLink,
            id: episode.id,
            episodeNumber: episode.episodeNumber,
          ),
        );
      }

      updatedSeasons.add(
        Season(seasonName: season.seasonName, episodes: updatedEpisodes),
      );
    }

    return ContentDetails(
      id: details.id,
      title: details.title,
      posterUrl: details.posterUrl,
      serverName: details.serverName,
      serverType: details.serverType,
      contentType: details.contentType,
      year: details.year,
      quality: details.quality,
      rating: details.rating,
      description: details.description,
      watchTime: details.watchTime,
      tags: details.tags,
      videoUrl: details.videoUrl,
      seasons: updatedSeasons,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(offlineModeProvider);
    final hasInitialData = widget.contentItem.initialData != null;

    if ((isOffline || hasInitialData) && hasInitialData) {
      late ContentDetails details;
      try {
        details = ContentDetails.fromMetadata(widget.contentItem.initialData!);

        if (details.isSeries && details.seasons != null) {
          details = _resolveOfflineEpisodeLinks(details);
        }
      } catch (e) {
        _logger.e('[build] Error loading offline content: $e', error: e);
        return _buildErrorWidget(
          'Failed to load offline content',
          e.toString(),
        );
      }

      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) {
            final videoPlayerState = _videoPlayerKey.currentState;
            if (videoPlayerState != null) {
              _nextUpdateIsImmediate = true;
              if (videoPlayerState.player != null) {
                final currentTime = videoPlayerState
                    .player!
                    .state
                    .position
                    .inSeconds
                    .toDouble();
                final duration = videoPlayerState
                    .player!
                    .state
                    .duration
                    .inSeconds
                    .toDouble();
                if (duration > 0) {
                  final server = FtpServersLocalData.getServerByName(
                    widget.contentItem.serverName,
                  );
                  if (server != null) {
                    _handleProgressUpdate(
                      details,
                      server.id,
                      widget.contentItem.serverName,
                      currentTime,
                      duration,
                      immediate: true,
                    );
                  }
                }
              }
            }
            try {
              final storage = ref.read(watchHistoryStorageProvider);
              await storage.flush();
            } catch (e) {
              _logger.e('[Back Button] Error flushing watch history: $e');
            }
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: _isVideoPlayerFullscreen
              ? Stack(
                  children: [
                    if (_isDragging)
                      Positioned.fill(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 100),
                          opacity:
                              (1.0 - _getSwipeProgress(context)).clamp(
                                0.0,
                                1.0,
                              ) *
                              0.25,
                          child: Container(color: AppColors.black),
                        ),
                      ),
                    GestureDetector(
                      onVerticalDragUpdate: _handleVerticalDragUpdate,
                      onVerticalDragEnd: _handleVerticalDragEnd,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        transform: Matrix4.translationValues(0, _dragOffset, 0),
                        child: Container(
                          color: _isDragging
                              ? AppColors.black.withValues(
                                  alpha:
                                      (1.0 - _getSectionHideProgress(context))
                                          .clamp(0.0, 1.0),
                                )
                              : AppColors.black,
                          child: _buildOfflineContent(details),
                        ),
                      ),
                    ),
                  ],
                )
              : SafeArea(
                  bottom: false,
                  child: Stack(
                    children: [
                      if (_isDragging)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 100),
                            opacity:
                                (1.0 - _getSwipeProgress(context)).clamp(
                                  0.0,
                                  1.0,
                                ) *
                                0.25,
                            child: Container(color: AppColors.black),
                          ),
                        ),
                      GestureDetector(
                        onVerticalDragUpdate: _handleVerticalDragUpdate,
                        onVerticalDragEnd: _handleVerticalDragEnd,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.translationValues(
                            0,
                            _dragOffset,
                            0,
                          ),
                          child: Container(
                            color: _isDragging
                                ? AppColors.black.withValues(
                                    alpha:
                                        (1.0 - _getSectionHideProgress(context))
                                            .clamp(0.0, 1.0),
                                  )
                                : AppColors.black,
                            child: _buildOfflineContent(details),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }

    final workingServersAsync = ref.watch(workingFtpServersProvider);
    final serverId = workingServersAsync.maybeWhen(
      data: (servers) => servers
          .where((s) => s.name == widget.contentItem.serverName)
          .firstOrNull
          ?.id,
      orElse: () => null,
    );

    if (serverId == null) {
      return _buildErrorWidget(
        'Server not found',
        'Unable to find server: ${widget.contentItem.serverName}',
      );
    }

    final detailsWithHistoryAsync = ref.watch(
      contentDetailsWithHistoryProvider((
        contentId: widget.contentItem.id,
        serverName: widget.contentItem.serverName,
        serverType: widget.contentItem.serverType,
        ftpServerId: serverId,
        initialData: widget.contentItem.initialData,
        initialSeasonNumber: widget.contentItem.initialSeasonNumber,
        initialEpisodeNumber: widget.contentItem.initialEpisodeNumber,
      )),
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          detailsWithHistoryAsync.whenData((data) {
            final videoPlayerState = _videoPlayerKey.currentState;
            if (videoPlayerState != null) {
              _nextUpdateIsImmediate = true;
              if (videoPlayerState.player != null) {
                final currentTime = videoPlayerState
                    .player!
                    .state
                    .position
                    .inSeconds
                    .toDouble();
                final duration = videoPlayerState
                    .player!
                    .state
                    .duration
                    .inSeconds
                    .toDouble();
                if (duration > 0) {
                  _handleProgressUpdate(
                    data.details,
                    serverId,
                    widget.contentItem.serverName,
                    currentTime,
                    duration,
                    immediate: true,
                  );
                }
              }
            }
          });
          try {
            final storage = ref.read(watchHistoryStorageProvider);
            await storage.flush();
          } catch (e) {
            _logger.e('[Back Button] Error flushing watch history: $e');
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _isVideoPlayerFullscreen
            ? detailsWithHistoryAsync.when(
                data: (data) {
                  if (data.initialPosition != null) {
                    _initialPosition = data.initialPosition;
                  }
                  WidgetsBinding.instance.addPostFrameCallback((_) async {
                    await _selectInitialEpisode(data.details);
                  });
                  return Stack(
                    children: [
                      if (_isDragging)
                        Positioned.fill(
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 100),
                            opacity:
                                (1.0 - _getSwipeProgress(context)).clamp(
                                  0.0,
                                  1.0,
                                ) *
                                0.25,
                            child: Container(color: AppColors.black),
                          ),
                        ),
                      GestureDetector(
                        onVerticalDragUpdate: _handleVerticalDragUpdate,
                        onVerticalDragEnd: _handleVerticalDragEnd,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.translationValues(
                            0,
                            _dragOffset,
                            0,
                          ),
                          child: Container(
                            color: _isDragging
                                ? AppColors.black.withValues(
                                    alpha:
                                        (1.0 - _getSectionHideProgress(context))
                                            .clamp(0.0, 1.0),
                                  )
                                : AppColors.black,
                            child: _buildContent(data.details),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
                        style: TextStyle(
                          color: AppColors.textMid,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textLow,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : SafeArea(
                bottom: false,
                child: detailsWithHistoryAsync.when(
                  data: (data) {
                    if (data.initialPosition != null) {
                      _initialPosition = data.initialPosition;
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await _selectInitialEpisode(data.details);
                    });
                    return Stack(
                      children: [
                        if (_isDragging)
                          Positioned.fill(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 100),
                              opacity:
                                  (1.0 - _getSwipeProgress(context)).clamp(
                                    0.0,
                                    1.0,
                                  ) *
                                  0.25,
                              child: Container(color: AppColors.black),
                            ),
                          ),
                        GestureDetector(
                          onVerticalDragUpdate: _handleVerticalDragUpdate,
                          onVerticalDragEnd: _handleVerticalDragEnd,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            transform: Matrix4.translationValues(
                              0,
                              _dragOffset,
                              0,
                            ),
                            child: Container(
                              color: _isDragging
                                  ? AppColors.black.withValues(
                                      alpha:
                                          (1.0 -
                                                  _getSectionHideProgress(
                                                    context,
                                                  ))
                                              .clamp(0.0, 1.0),
                                    )
                                  : AppColors.black,
                              child: _buildContent(data.details),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
                          style: TextStyle(
                            color: AppColors.textMid,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textLow,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildErrorWidget(String title, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 64),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(color: AppColors.textMid, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textLow, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterImage(String posterUrl) {
    final isLocalFile =
        posterUrl.startsWith('/') || posterUrl.contains('/posters/');

    if (isLocalFile) {
      final file = File(posterUrl);
      return Image.file(
        file,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(Icons.movie, size: 64, color: AppColors.textLow),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: posterUrl,
      fit: BoxFit.cover,
      errorWidget: (context, url, error) => const Center(
        child: Icon(Icons.movie, size: 64, color: AppColors.textLow),
      ),
    );
  }

  Widget _buildFullscreenVideoPlayer(
    ContentDetails details,
    String videoUrl,
    bool isOffline,
  ) {
    return Container(
      color: AppColors.black,
      child: Center(
        child: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _notifyPlayerReceived();
            });

            Duration? resolvedInitialPosition = _initialPosition;

            if (!isOffline) {
              final workingServersAsync = ref.watch(workingFtpServersProvider);
              final serverId = workingServersAsync.maybeWhen(
                data: (servers) => servers
                    .where((s) => s.name == widget.contentItem.serverName)
                    .firstOrNull
                    ?.id,
                orElse: () => null,
              );

              if (serverId != null) {
                final watchHistoryAsync = ref.watch(
                  contentWatchHistoryProvider((
                    ftpServerId: serverId,
                    contentId: widget.contentItem.id,
                  )),
                );

                if (watchHistoryAsync.hasValue &&
                    watchHistoryAsync.value != null) {
                  final watchHistory = watchHistoryAsync.value!;
                  Duration? position = resolvedInitialPosition;

                  if (_currentSeasonNumber != null &&
                      _currentEpisodeNumber != null &&
                      watchHistory.seriesProgress != null) {
                    final backendSeason = watchHistory.seriesProgress!
                        .where((s) => s.seasonNumber == _currentSeasonNumber)
                        .firstOrNull;

                    if (backendSeason != null) {
                      final backendEpisode = backendSeason.episodes
                          .where(
                            (e) => e.episodeNumber == _currentEpisodeNumber,
                          )
                          .firstOrNull;

                      if (backendEpisode != null &&
                          backendEpisode.progress.currentTime > 0 &&
                          backendEpisode.progress.duration > 0) {
                        final currentTime = backendEpisode.progress.currentTime;
                        final duration = backendEpisode.progress.duration;
                        final percentage = (currentTime / duration) * 100;
                        if (percentage < 95) {
                          position = Duration(seconds: currentTime.toInt());
                        } else {
                          position = Duration.zero;
                        }
                      } else {
                        position = Duration.zero;
                      }
                    } else {
                      position = Duration.zero;
                    }
                  }

                  if (position != null) {
                    resolvedInitialPosition = position;
                  }
                }
              }
            } else {
              final server = FtpServersLocalData.getServerByName(
                widget.contentItem.serverName,
              );

              if (server != null) {
                final watchHistoryAsync = ref.watch(
                  contentWatchHistoryProvider((
                    ftpServerId: server.id,
                    contentId: widget.contentItem.id,
                  )),
                );

                if (watchHistoryAsync.hasValue &&
                    watchHistoryAsync.value != null) {
                  if (_currentSeasonNumber != null &&
                      _currentEpisodeNumber != null &&
                      watchHistoryAsync.value!.seriesProgress != null) {
                    final season = watchHistoryAsync.value!.seriesProgress!
                        .where((s) => s.seasonNumber == _currentSeasonNumber)
                        .firstOrNull;

                    if (season != null) {
                      final episode = season.episodes
                          .where(
                            (e) => e.episodeNumber == _currentEpisodeNumber,
                          )
                          .firstOrNull;

                      if (episode != null &&
                          episode.progress.currentTime > 0 &&
                          episode.progress.duration > 0) {
                        final percentage =
                            (episode.progress.currentTime /
                                episode.progress.duration) *
                            100;
                        if (percentage < 95 &&
                            episode.progress.currentTime > 0) {
                          resolvedInitialPosition = Duration(
                            seconds: episode.progress.currentTime.toInt(),
                          );
                        }
                      } else {
                        resolvedInitialPosition = Duration.zero;
                      }
                    } else {
                      resolvedInitialPosition = Duration.zero;
                    }
                  } else if (watchHistoryAsync.value!.progress != null &&
                      watchHistoryAsync.value!.progress!.currentTime > 0 &&
                      watchHistoryAsync.value!.progress!.duration > 0) {
                    final currentTime =
                        watchHistoryAsync.value!.progress!.currentTime;
                    final duration =
                        watchHistoryAsync.value!.progress!.duration;
                    final percentage = (currentTime / duration) * 100;

                    if (percentage >= 95) {
                      resolvedInitialPosition = Duration.zero;
                    } else if (currentTime > 5) {
                      resolvedInitialPosition = Duration(
                        seconds: currentTime.toInt(),
                      );
                    }
                  }
                }
              }
            }

            final episodeControls = _buildEpisodeNavigationConfig(details);
            final playbackGeneration = _playbackGeneration;

            return _VideoPlayerWidgetWrapper(
              key: _videoPlayerKey,
              videoUrl: _resolveVideoUrl(ref, videoUrl),
              autoPlay: true,
              initialPosition: resolvedInitialPosition,
              receivedPlayer: _receivedPlayer,
              receivedController: _receivedVideoController,
              showEpisodeControls: episodeControls.showEpisodeControls,
              canGoToPreviousEpisode: episodeControls.canGoToPreviousEpisode,
              canGoToNextEpisode: episodeControls.canGoToNextEpisode,
              onPreviousEpisode: episodeControls.onPreviousEpisode,
              onNextEpisode: episodeControls.onNextEpisode,
              pipDragProgress: _getSwipeProgress(context),
              onRequestImmediateSave: () {
                setState(() {
                  _nextUpdateIsImmediate = true;
                });
              },
              onProgressUpdate: (currentTime, duration) {
                if (playbackGeneration != _playbackGeneration) {
                  return;
                }
                _initialPosition = Duration(seconds: currentTime.toInt());

                final server = FtpServersLocalData.getServerByName(
                  widget.contentItem.serverName,
                );
                if (server != null) {
                  final immediate = _nextUpdateIsImmediate;
                  _nextUpdateIsImmediate = false;
                  _handleProgressUpdate(
                    details,
                    server.id,
                    server.name,
                    currentTime,
                    duration,
                    immediate: immediate,
                  );
                }
              },
              onFullscreenChanged: (isFullscreen) {
                setState(() {
                  _isVideoPlayerFullscreen = isFullscreen;
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOfflineContent(ContentDetails details) {
    if (details.isSeries &&
        details.seasons != null &&
        details.seasons!.isNotEmpty) {
      if (_currentVideoUrl == null) {
        if (_currentSeasonNumber == null || _currentEpisodeNumber == null) {
          if (widget.contentItem.initialSeasonNumber != null &&
              widget.contentItem.initialEpisodeNumber != null) {
            _currentSeasonNumber = widget.contentItem.initialSeasonNumber;
            _currentEpisodeNumber = widget.contentItem.initialEpisodeNumber;

            final seasonIndex = details.seasons!.indexWhere((season) {
              final seasonNum = _resolveSeasonNumber(
                season,
                details.seasons!.indexOf(season),
              );
              return seasonNum == _currentSeasonNumber;
            });

            if (seasonIndex >= 0) {
              final season = details.seasons![seasonIndex];
              final episodeIndex = _currentEpisodeNumber! - 1;

              if (episodeIndex >= 0 && episodeIndex < season.episodes.length) {
                final episode = season.episodes[episodeIndex];
                _currentEpisodeId =
                    episode.id ??
                    '${_currentSeasonNumber}_$_currentEpisodeNumber';
                _currentEpisodeTitle = episode.title;
              }
            }
          } else {
            final firstDownloaded = _findFirstDownloadedEpisode(details);
            if (firstDownloaded != null) {
              _currentSeasonNumber = firstDownloaded.seasonNumber;
              _currentEpisodeNumber = firstDownloaded.episodeNumber;
              _currentEpisodeId = firstDownloaded.episodeId;
              _currentEpisodeTitle = firstDownloaded.episodeTitle;
            } else {
              final firstSeason = details.seasons!.first;
              if (firstSeason.episodes.isNotEmpty) {
                final firstEpisode = firstSeason.episodes.first;
                _currentSeasonNumber = _extractSeasonNumber(
                  firstSeason.seasonName,
                );
                _currentEpisodeNumber = firstEpisode.episodeNumber ?? 1;
                _currentEpisodeId = firstEpisode.id;
                _currentEpisodeTitle = firstEpisode.title;
              }
            }
          }
        }

        if (_currentSeasonNumber != null && _currentEpisodeNumber != null) {
          final downloadedContent = ref.read(
            downloadedContentItemProvider((
              contentId: widget.contentItem.id,
              seasonNumber: _currentSeasonNumber!,
              episodeNumber: _currentEpisodeNumber!,
            )),
          );

          if (downloadedContent != null &&
              downloadedContent.localPath.isNotEmpty) {
            _currentVideoUrl = downloadedContent.localPath;
          } else {
            final season = details.seasons!.firstWhere(
              (s) => _extractSeasonNumber(s.seasonName) == _currentSeasonNumber,
              orElse: () => details.seasons!.first,
            );
            final episodeIndex = _currentEpisodeNumber! - 1;
            if (episodeIndex >= 0 && episodeIndex < season.episodes.length) {
              final episode = season.episodes[episodeIndex];
              _currentVideoUrl = episode.link;
            }
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref
                .read(currentPlayingContentProvider.notifier)
                .state = CurrentPlayingContent(
              contentId: widget.contentItem.id,
              seasonNumber: _currentSeasonNumber,
              episodeNumber: _currentEpisodeNumber,
            );
          });
        }
      }
    }

    final videoUrl = _currentVideoUrl ?? details.videoUrl;

    if (_isVideoPlayerFullscreen && videoUrl != null && videoUrl.isNotEmpty) {
      return _buildFullscreenVideoPlayer(details, videoUrl, true);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentVideoUrl == null && videoUrl != null && videoUrl.isNotEmpty) {
        setState(() {
          _currentVideoUrl = videoUrl;
        });

        if (!details.isSeries) {
          ref
              .read(currentPlayingContentProvider.notifier)
              .state = CurrentPlayingContent(
            contentId: widget.contentItem.id,
            seasonNumber: null,
            episodeNumber: null,
          );
        }
      }
    });

    if (details.isSeries && details.seasons != null) {
      if (_tabController == null) {
        int initialIndex = 0;
        if (_currentSeasonNumber != null && details.seasons != null) {
          final seasonIndex = details.seasons!.indexWhere((season) {
            final seasonNum = _extractSeasonNumber(season.seasonName);
            return seasonNum == _currentSeasonNumber;
          });
          if (seasonIndex >= 0) {
            initialIndex = seasonIndex;
          }
        } else if (widget.contentItem.initialSeasonNumber != null &&
            details.seasons != null) {
          final seasonIndex = details.seasons!.indexWhere((season) {
            final seasonNum = _extractSeasonNumber(season.seasonName);
            return seasonNum == widget.contentItem.initialSeasonNumber;
          });
          if (seasonIndex >= 0) {
            initialIndex = seasonIndex;
            _currentSeasonNumber = widget.contentItem.initialSeasonNumber;
            _currentEpisodeNumber = widget.contentItem.initialEpisodeNumber;
            _currentEpisodeId = widget.contentItem.initialEpisodeId;
          }
        } else if (_currentSeasonNumber == null &&
            details.seasons!.isNotEmpty) {
          _currentSeasonNumber = _extractSeasonNumber(
            details.seasons!.first.seasonName,
          );
        }
        _tabController = TabController(
          length: details.seasons!.length,
          vsync: this,
          initialIndex: initialIndex,
        );
      }
    }

    final sectionOpacity = _isDragging
        ? 1.0 - _getSectionHideProgress(context)
        : 1.0;
    final videoScale = _isDragging ? _getVideoScaleProgress(context) : 1.0;
    final videoHorizontalOffset = _isDragging
        ? _getVideoHorizontalOffset(context)
        : 0.0;

    return Column(
      children: [
        if (videoUrl != null && videoUrl.isNotEmpty)
          Transform.translate(
            offset: Offset(videoHorizontalOffset, 0),
            child: Transform.scale(
              scale: videoScale,
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 250,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    _getVideoCornerRadiusProgress(context) * 12.0,
                  ),
                  child: Stack(
                    children: [
                      Builder(
                        builder: (context) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            _notifyPlayerReceived();
                          });

                          Duration? resolvedInitialPosition = _initialPosition;

                          final server = FtpServersLocalData.getServerByName(
                            widget.contentItem.serverName,
                          );

                          if (server != null) {
                            final watchHistoryAsync = ref.watch(
                              contentWatchHistoryProvider((
                                ftpServerId: server.id,
                                contentId: widget.contentItem.id,
                              )),
                            );

                            if (watchHistoryAsync.hasValue &&
                                watchHistoryAsync.value != null) {
                              if (_currentSeasonNumber != null &&
                                  _currentEpisodeNumber != null &&
                                  watchHistoryAsync.value!.seriesProgress !=
                                      null) {
                                final season = watchHistoryAsync
                                    .value!
                                    .seriesProgress!
                                    .where(
                                      (s) =>
                                          s.seasonNumber ==
                                          _currentSeasonNumber,
                                    )
                                    .firstOrNull;

                                if (season != null) {
                                  final episode = season.episodes
                                      .where(
                                        (e) =>
                                            e.episodeNumber ==
                                            _currentEpisodeNumber,
                                      )
                                      .firstOrNull;

                                  if (episode != null &&
                                      episode.progress.currentTime > 0 &&
                                      episode.progress.duration > 0) {
                                    final percentage =
                                        (episode.progress.currentTime /
                                            episode.progress.duration) *
                                        100;
                                    if (percentage < 95 &&
                                        episode.progress.currentTime > 0) {
                                      resolvedInitialPosition = Duration(
                                        seconds: episode.progress.currentTime
                                            .toInt(),
                                      );
                                    }
                                  } else {
                                    resolvedInitialPosition = Duration.zero;
                                  }
                                } else {
                                  resolvedInitialPosition = Duration.zero;
                                }
                              } else if (watchHistoryAsync.value!.progress !=
                                      null &&
                                  watchHistoryAsync
                                          .value!
                                          .progress!
                                          .currentTime >
                                      0 &&
                                  watchHistoryAsync.value!.progress!.duration >
                                      0) {
                                final currentTime = watchHistoryAsync
                                    .value!
                                    .progress!
                                    .currentTime;
                                final duration =
                                    watchHistoryAsync.value!.progress!.duration;
                                final percentage =
                                    (currentTime / duration) * 100;

                                if (percentage >= 95) {
                                  resolvedInitialPosition = Duration.zero;
                                } else if (currentTime > 5) {
                                  resolvedInitialPosition = Duration(
                                    seconds: currentTime.toInt(),
                                  );
                                }
                              }
                            }
                          }

                          final episodeControls = _buildEpisodeNavigationConfig(
                            details,
                          );
                          final playbackGeneration = _playbackGeneration;

                          return _VideoPlayerWidgetWrapper(
                            key: _videoPlayerKey,
                            videoUrl: _resolveVideoUrl(ref, videoUrl),
                            autoPlay: true,
                            initialPosition: resolvedInitialPosition,
                            receivedPlayer: _receivedPlayer,
                            receivedController: _receivedVideoController,
                            showEpisodeControls:
                                episodeControls.showEpisodeControls,
                            canGoToPreviousEpisode:
                                episodeControls.canGoToPreviousEpisode,
                            canGoToNextEpisode:
                                episodeControls.canGoToNextEpisode,
                            onPreviousEpisode:
                                episodeControls.onPreviousEpisode,
                            onNextEpisode: episodeControls.onNextEpisode,
                            pipDragProgress: _getSwipeProgress(context),
                            onRequestImmediateSave: () {
                              setState(() {
                                _nextUpdateIsImmediate = true;
                              });
                            },
                            onProgressUpdate: (currentTime, duration) {
                              if (playbackGeneration != _playbackGeneration) {
                                return;
                              }
                              _initialPosition = Duration(
                                seconds: currentTime.toInt(),
                              );

                              final server =
                                  FtpServersLocalData.getServerByName(
                                    widget.contentItem.serverName,
                                  );
                              if (server != null) {
                                final immediate = _nextUpdateIsImmediate;
                                _nextUpdateIsImmediate = false;
                                _handleProgressUpdate(
                                  details,
                                  server.id,
                                  server.name,
                                  currentTime,
                                  duration,
                                  immediate: immediate,
                                );
                              }
                            },
                            onFullscreenChanged: (isFullscreen) {
                              setState(() {
                                _isVideoPlayerFullscreen = isFullscreen;
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: sectionOpacity,
                  child: ContentDetailsSection(
                    details: details,
                    onWatchStatusDropdown: _buildWatchStatusDropdown,
                    onDownloadButton: (details) =>
                        _buildOfflineDownloadButton(details),
                    isMinimizable: details.isSeries,
                  ),
                ),
                if (details.isSeries && details.seasons != null)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: sectionOpacity,
                    child: Builder(
                      builder: (context) {
                        List<SeasonProgress>? seriesProgress;
                        final server = FtpServersLocalData.getServerByName(
                          widget.contentItem.serverName,
                        );

                        if (server != null) {
                          final watchHistoryAsync = ref.watch(
                            contentWatchHistoryProvider((
                              ftpServerId: server.id,
                              contentId: widget.contentItem.id,
                            )),
                          );

                          if (watchHistoryAsync.hasValue &&
                              watchHistoryAsync.value != null) {
                            seriesProgress =
                                watchHistoryAsync.value!.seriesProgress;
                            _liveSeriesProgress = seriesProgress;
                          }
                        }

                        return SeasonsSection(
                          seasons: details.seasons!,
                          currentSeasonNumber: _currentSeasonNumber,
                          currentEpisodeNumber: _currentEpisodeNumber,
                          currentEpisodeId: _currentEpisodeId,
                          seriesProgress: _liveSeriesProgress ?? seriesProgress,
                          progressUpdateCounter: _progressUpdateCounter,
                          useSeasonNameForNumber: true,
                          isEpisodeAvailable: (seasonNumber, episodeNumber) {
                            final downloaded = ref.read(
                              downloadedContentItemProvider((
                                contentId: widget.contentItem.id,
                                seasonNumber: seasonNumber,
                                episodeNumber: episodeNumber,
                              )),
                            );
                            return downloaded != null &&
                                downloaded.localPath.isNotEmpty;
                          },
                          onEpisodeTap:
                              (season, seasonNumber, episodeNumber, episode) {
                                _handleOfflineEpisodeTap(
                                  details,
                                  season,
                                  seasonNumber,
                                  episodeNumber,
                                  episode,
                                );
                              },
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(ContentDetails details) {
    final videoUrl = _currentVideoUrl ?? details.videoUrl;

    if (_isVideoPlayerFullscreen && videoUrl != null && videoUrl.isNotEmpty) {
      return _buildFullscreenVideoPlayer(details, videoUrl, false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentVideoUrl == null && videoUrl != null && videoUrl.isNotEmpty) {
        setState(() {
          _currentVideoUrl = videoUrl;
        });

        if (!details.isSeries) {
          ref
              .read(currentPlayingContentProvider.notifier)
              .state = CurrentPlayingContent(
            contentId: widget.contentItem.id,
            seasonNumber: null,
            episodeNumber: null,
          );
        }
      }
    });

    if (details.isSeries && details.seasons != null) {
      if (_tabController == null) {
        int initialIndex = 0;
        if (_currentSeasonNumber != null && details.seasons != null) {
          final seasonIndex = details.seasons!.indexWhere((season) {
            final seasonNum = _extractSeasonNumber(season.seasonName);
            return seasonNum == _currentSeasonNumber;
          });
          if (seasonIndex >= 0) {
            initialIndex = seasonIndex;
          }
        } else if (widget.contentItem.initialSeasonNumber != null &&
            details.seasons != null) {
          final seasonIndex = details.seasons!.indexWhere((season) {
            final seasonNum = _extractSeasonNumber(season.seasonName);
            return seasonNum == widget.contentItem.initialSeasonNumber;
          });
          if (seasonIndex >= 0) {
            initialIndex = seasonIndex;
            _currentSeasonNumber = widget.contentItem.initialSeasonNumber;
            _currentEpisodeNumber = widget.contentItem.initialEpisodeNumber;
            _currentEpisodeId = widget.contentItem.initialEpisodeId;
          }
        }
        _tabController = TabController(
          length: details.seasons!.length,
          vsync: this,
          initialIndex: initialIndex,
        );
      }
    }

    final sectionOpacity = _isDragging
        ? 1.0 - _getSectionHideProgress(context)
        : 1.0;
    final videoScale = _isDragging ? _getVideoScaleProgress(context) : 1.0;
    final videoHorizontalOffset = _isDragging
        ? _getVideoHorizontalOffset(context)
        : 0.0;

    return Column(
      children: [
        if (videoUrl != null && videoUrl.isNotEmpty)
          Flexible(
            flex: 0,
            child: Transform.translate(
              offset: Offset(videoHorizontalOffset, 0),
              child: Transform.scale(
                scale: videoScale,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  height: 250,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                      _getVideoCornerRadiusProgress(context) * 12.0,
                    ),
                    child: Stack(
                      children: [
                        Builder(
                          builder: (context) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _notifyPlayerReceived();
                            });
                            final workingServersAsync = ref.watch(
                              workingFtpServersProvider,
                            );
                            final serverId = workingServersAsync.maybeWhen(
                              data: (servers) => servers
                                  .where(
                                    (s) =>
                                        s.name == widget.contentItem.serverName,
                                  )
                                  .firstOrNull
                                  ?.id,
                              orElse: () => null,
                            );

                            Duration? resolvedInitialPosition =
                                _initialPosition;

                            if (serverId != null) {
                              final watchHistoryAsync = ref.watch(
                                contentWatchHistoryProvider((
                                  ftpServerId: serverId,
                                  contentId: widget.contentItem.id,
                                )),
                              );

                              if (watchHistoryAsync.hasValue &&
                                  watchHistoryAsync.value != null) {
                                final watchHistory = watchHistoryAsync.value!;

                                Duration? position = resolvedInitialPosition;

                                if (_currentSeasonNumber != null &&
                                    _currentEpisodeNumber != null &&
                                    watchHistory.seriesProgress != null) {
                                  final backendSeason = watchHistory
                                      .seriesProgress!
                                      .where(
                                        (s) =>
                                            s.seasonNumber ==
                                            _currentSeasonNumber,
                                      )
                                      .firstOrNull;

                                  if (backendSeason != null) {
                                    final backendEpisode = backendSeason
                                        .episodes
                                        .where(
                                          (e) =>
                                              e.episodeNumber ==
                                              _currentEpisodeNumber,
                                        )
                                        .firstOrNull;

                                    if (backendEpisode != null &&
                                        backendEpisode.progress.currentTime >
                                            0 &&
                                        backendEpisode.progress.duration > 0) {
                                      final currentTime =
                                          backendEpisode.progress.currentTime;
                                      final duration =
                                          backendEpisode.progress.duration;
                                      final percentage =
                                          (currentTime / duration) * 100;
                                      if (percentage < 95) {
                                        position = Duration(
                                          seconds: currentTime.toInt(),
                                        );
                                      } else {
                                        position = Duration.zero;
                                      }
                                    } else {
                                      position = Duration.zero;
                                    }
                                  } else {
                                    position = Duration.zero;
                                  }
                                } else if (!details.isSeries &&
                                    watchHistory.progress != null &&
                                    watchHistory.progress!.currentTime > 0) {
                                  position = Duration(
                                    seconds: watchHistory.progress!.currentTime
                                        .toInt(),
                                  );
                                }

                                if (position != null) {
                                  resolvedInitialPosition = position;
                                }
                              }
                            }

                            final episodeControls =
                                _buildEpisodeNavigationConfig(details);
                            final playbackGeneration = _playbackGeneration;

                            return _VideoPlayerWidgetWrapper(
                              key: _videoPlayerKey,
                              videoUrl: _resolveVideoUrl(ref, videoUrl),
                              autoPlay: true,
                              initialPosition: resolvedInitialPosition,
                              receivedPlayer: _receivedPlayer,
                              receivedController: _receivedVideoController,
                              showEpisodeControls:
                                  episodeControls.showEpisodeControls,
                              canGoToPreviousEpisode:
                                  episodeControls.canGoToPreviousEpisode,
                              canGoToNextEpisode:
                                  episodeControls.canGoToNextEpisode,
                              onPreviousEpisode:
                                  episodeControls.onPreviousEpisode,
                              onNextEpisode: episodeControls.onNextEpisode,
                              pipDragProgress: _getSwipeProgress(context),
                              onFullscreenChanged: (isFullscreen) {
                                setState(() {
                                  _isVideoPlayerFullscreen = isFullscreen;
                                });
                              },
                              onRequestImmediateSave: () {
                                setState(() {
                                  _nextUpdateIsImmediate = true;
                                });
                              },
                              onProgressUpdate: (currentTime, duration) {
                                if (playbackGeneration != _playbackGeneration) {
                                  return;
                                }
                                final server =
                                    FtpServersLocalData.getServerByName(
                                      widget.contentItem.serverName,
                                    );
                                if (server != null) {
                                  final immediate = _nextUpdateIsImmediate;
                                  _nextUpdateIsImmediate = false;
                                  _handleProgressUpdate(
                                    details,
                                    server.id,
                                    server.name,
                                    currentTime,
                                    duration,
                                    immediate: immediate,
                                  );
                                }
                              },
                            );
                          },
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: SafeArea(child: const SizedBox.shrink()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            height: 250,
            color: AppColors.black,
            child: details.posterUrl.isNotEmpty
                ? _buildPosterImage(details.posterUrl)
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
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: sectionOpacity,
                  child: ContentDetailsSection(
                    details: details,
                    onWatchStatusDropdown: _buildWatchStatusDropdown,
                    onDownloadButton: (details) =>
                        _buildDownloadButton(details),
                    skipInitialAnimation:
                        _activatedPipFromHere || _receivedPlayer != null,
                    isMinimizable: details.isSeries,
                  ),
                ),
              ),
              if (details.isSeries && details.seasons != null)
                SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: sectionOpacity,
                    child: Builder(
                      builder: (context) {
                        List<SeasonProgress>? seriesProgress;
                        final serverId = _resolveCurrentServerId();

                        if (serverId != null) {
                          final watchHistoryAsync = ref.watch(
                            contentWatchHistoryProvider((
                              ftpServerId: serverId,
                              contentId: widget.contentItem.id,
                            )),
                          );

                          if (watchHistoryAsync.hasValue &&
                              watchHistoryAsync.value != null) {
                            seriesProgress =
                                watchHistoryAsync.value!.seriesProgress;
                            _liveSeriesProgress = seriesProgress;
                          }
                        }

                        return SeasonsSection(
                          seasons: details.seasons!,
                          tabController: _tabController!,
                          currentVideoUrl: _currentVideoUrl,
                          currentSeasonNumber: _currentSeasonNumber,
                          currentEpisodeNumber: _currentEpisodeNumber,
                          onEpisodeTap: _handleEpisodeTap,
                          onEpisodeDownload:
                              (season, seasonNumber, episodeNumber, episode) =>
                                  _buildEpisodeDownloadButton(
                                    details,
                                    season,
                                    seasonNumber,
                                    episodeNumber,
                                    episode,
                                  ),
                          enablePeriodicRebuild: true,
                          seriesProgress: _liveSeriesProgress ?? seriesProgress,
                          progressUpdateCounter: _progressUpdateCounter,
                        );
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _ensureEpisodeInLiveProgress(
    int seasonNumber,
    int episodeNumber,
    String episodeTitle,
  ) {
    _liveSeriesProgress ??= [];

    final seasonIndex = _liveSeriesProgress!.indexWhere(
      (s) => s.seasonNumber == seasonNumber,
    );

    if (seasonIndex == -1) {
      final newEpisodeId =
          '${widget.contentItem.id}_s${seasonNumber}_e$episodeNumber';
      _liveSeriesProgress!.add(
        SeasonProgress(
          seasonNumber: seasonNumber,
          episodes: [
            EpisodeProgress(
              episodeNumber: episodeNumber,
              episodeId: newEpisodeId,
              episodeTitle: episodeTitle,
              status: WatchStatus.watching,
              progress: ProgressInfo(
                currentTime: 0,
                duration: 0,
                percentage: 0,
              ),
              lastWatchedAt: DateTime.now(),
            ),
          ],
        ),
      );
    } else {
      final season = _liveSeriesProgress![seasonIndex];
      final episodeIndex = season.episodes.indexWhere(
        (e) => e.episodeNumber == episodeNumber,
      );

      if (episodeIndex == -1) {
        final newEpisodeId =
            '${widget.contentItem.id}_s${seasonNumber}_e$episodeNumber';
        season.episodes.add(
          EpisodeProgress(
            episodeNumber: episodeNumber,
            episodeId: newEpisodeId,
            episodeTitle: episodeTitle,
            status: WatchStatus.watching,
            progress: ProgressInfo(currentTime: 0, duration: 0, percentage: 0),
            lastWatchedAt: DateTime.now(),
          ),
        );
      } else {}
    }
  }

  void _handleEpisodeTap(
    Season season,
    int seasonNumber,
    int episodeNumber,
    Episode episode,
  ) async {
    final server = FtpServersLocalData.getServerByName(
      widget.contentItem.serverName,
    );

    String? serverId = server?.id;
    String? serverName = server?.name;

    if (serverId == null || serverName == null) {
      final workingServersAsync = ref.read(workingFtpServersProvider);
      serverId = workingServersAsync.maybeWhen(
        data: (servers) => servers
            .where((s) => s.name == widget.contentItem.serverName)
            .firstOrNull
            ?.id,
        orElse: () => null,
      );

      serverName = workingServersAsync.maybeWhen(
        data: (servers) => servers
            .where((s) => s.name == widget.contentItem.serverName)
            .firstOrNull
            ?.name,
        orElse: () => null,
      );
    }

    if (serverId != null && serverName != null) {
      _playbackGeneration++;
      final detailsAsync = ref.read(
        contentDetailsProvider((
          contentId: widget.contentItem.id,
          serverName: widget.contentItem.serverName,
          serverType: widget.contentItem.serverType,
          initialData: null,
        )),
      );

      if (detailsAsync.hasValue) {
        _saveCurrentProgress(
          detailsAsync.value!,
          serverId,
          serverName,
          immediate: true,
        );
      }

      try {
        final storage = ref.read(watchHistoryStorageProvider);
        await storage.flush();
      } catch (e) {
        _logger.e('[Episode Switch] Error flushing pending writes: $e');
      }

      final newEpisodeId =
          '${widget.contentItem.id}_s${seasonNumber}_e$episodeNumber';

      ref.read(playbackStateProvider.notifier).clearPlaybackState();

      final newWrapperKey = GlobalKey<_VideoPlayerWidgetWrapperState>();

      Duration? newPosition;
      newPosition = await _fetchInitialPositionForEpisode(
        serverId,
        seasonNumber,
        episodeNumber,
      );

      newPosition ??= Duration.zero;

      if (!mounted) return;

      setState(() {
        final isOffline = ref.read(offlineModeProvider);
        String resolvedUrl = episode.link;

        if (isOffline) {
          final downloadedContent = ref.read(
            downloadedContentItemProvider((
              contentId: widget.contentItem.id,
              seasonNumber: seasonNumber,
              episodeNumber: episodeNumber,
            )),
          );
          if (downloadedContent != null &&
              downloadedContent.localPath.isNotEmpty) {
            resolvedUrl = downloadedContent.localPath;
          }
        }

        _videoPlayerKey = newWrapperKey;
        _receivedPlayer = null;
        _receivedVideoController = null;
        _currentVideoUrl = resolvedUrl;
        _currentSeasonNumber = seasonNumber;
        _currentEpisodeNumber = episodeNumber;
        _currentEpisodeId = newEpisodeId;
        _currentEpisodeTitle = episode.title;
        _initialPosition = newPosition;
        _hasTriggeredAutoComplete = false;

        _ensureEpisodeInLiveProgress(
          seasonNumber,
          episodeNumber,
          episode.title,
        );
        if (_liveSeriesProgress != null) {
          _liveSeriesProgress = [..._liveSeriesProgress!];
          _progressUpdateCounter++;
        }
      });

      ref
          .read(currentPlayingContentProvider.notifier)
          .state = CurrentPlayingContent(
        contentId: widget.contentItem.id,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
      );
    }
  }

  Widget _buildDownloadButton(ContentDetails details) {
    final server = FtpServersLocalData.getServerByName(
      widget.contentItem.serverName,
    );

    if (server == null) return const SizedBox.shrink();
    if (details.videoUrl == null || details.videoUrl!.isEmpty) {
      return const SizedBox.shrink();
    }

    return DownloadButton(
      contentId: widget.contentItem.id,
      title: details.title,
      posterUrl: details.posterUrl,
      description: details.description ?? '',
      serverName: widget.contentItem.serverName,
      serverType: widget.contentItem.serverType,
      ftpServerId: server.id,
      contentType: details.contentType,
      videoUrl: details.videoUrl!,
      year: details.year,
      quality: details.quality,
      rating: details.rating,
      metadata: details.toMetadata(),
    );
  }

  Widget _buildEpisodeDownloadButton(
    ContentDetails details,
    Season season,
    int seasonNumber,
    int episodeNumber,
    Episode episode,
  ) {
    final server = FtpServersLocalData.getServerByName(
      widget.contentItem.serverName,
    );

    if (server == null) return const SizedBox.shrink();
    if (episode.link.isEmpty) return const SizedBox.shrink();

    return DownloadButton(
      contentId: widget.contentItem.id,
      title: details.title,
      posterUrl: details.posterUrl,
      description: details.description ?? '',
      serverName: widget.contentItem.serverName,
      serverType: widget.contentItem.serverType,
      ftpServerId: server.id,
      contentType: details.contentType,
      videoUrl: episode.link,
      year: details.year,
      quality: details.quality,
      rating: details.rating,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
      episodeTitle: episode.title,
      seriesTitle: details.title,
      totalSeasons: details.seasons?.length,
      metadata: details.toMetadata(),
      isCompact: true,
    );
  }

  Widget _buildWatchStatusDropdown(ContentDetails details) {
    final server = FtpServersLocalData.getServerByName(
      widget.contentItem.serverName,
    );

    if (server == null) {
      return const SizedBox.shrink();
    }

    return WatchStatusDropdown(
      ftpServerId: server.id,
      serverName: server.name,
      serverType: widget.contentItem.serverType,
      contentType: details.contentType,
      contentId: widget.contentItem.id,
      contentTitle: details.title,
      metadata: {
        'serverName': widget.contentItem.serverName,
        'posterUrl': details.posterUrl,
        'year': details.year,
        'quality': details.quality,
      },
    );
  }

  Widget _buildOfflineDownloadButton(ContentDetails details) {
    final server = FtpServersLocalData.getServerByName(
      widget.contentItem.serverName,
    );

    if (server == null) return const SizedBox.shrink();

    final videoUrl = details.videoUrl;
    if (details.isSeries) {
      return const SizedBox.shrink();
    }

    if (videoUrl == null || videoUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return DownloadButton(
      contentId: widget.contentItem.id,
      title: details.title,
      posterUrl: details.posterUrl,
      description: details.description ?? '',
      serverName: widget.contentItem.serverName,
      serverType: widget.contentItem.serverType,
      ftpServerId: server.id,
      contentType: details.contentType,
      videoUrl: videoUrl,
      year: details.year,
      quality: details.quality,
      rating: details.rating,
      metadata: details.toMetadata(),
    );
  }

  Future<void> _handleOfflineEpisodeTap(
    ContentDetails details,
    Season season,
    int seasonNumber,
    int episodeNumber,
    Episode episode,
  ) async {
    final server = FtpServersLocalData.getServerByName(
      widget.contentItem.serverName,
    );

    if (server != null) {
      _saveCurrentProgress(details, server.id, server.name, immediate: true);

      try {
        final storage = ref.read(watchHistoryStorageProvider);
        await storage.flush();
      } catch (e) {
        _logger.e('[Offline Episode Switch] Error flushing pending writes: $e');
      }
    }

    final newEpisodeId =
        '${widget.contentItem.id}_s${seasonNumber}_e$episodeNumber';

    ref.read(playbackStateProvider.notifier).clearPlaybackState();

    final newWrapperKey = GlobalKey<_VideoPlayerWidgetWrapperState>();

    Duration? newPosition;
    if (server != null) {
      newPosition = await _fetchInitialPositionForEpisode(
        server.id,
        seasonNumber,
        episodeNumber,
      );
    }

    newPosition ??= Duration.zero;

    if (!mounted) return;

    setState(() {
      final downloadedContent = ref.read(
        downloadedContentItemProvider((
          contentId: widget.contentItem.id,
          seasonNumber: seasonNumber,
          episodeNumber: episodeNumber,
        )),
      );

      String resolvedUrl = episode.link;
      if (downloadedContent != null && downloadedContent.localPath.isNotEmpty) {
        resolvedUrl = downloadedContent.localPath;
      }

      _videoPlayerKey = newWrapperKey;
      _receivedPlayer = null;
      _receivedVideoController = null;
      _currentVideoUrl = resolvedUrl;
      _currentSeasonNumber = seasonNumber;
      _currentEpisodeNumber = episodeNumber;
      _currentEpisodeId = newEpisodeId;
      _currentEpisodeTitle = episode.title;
      _initialPosition = newPosition;
      _hasTriggeredAutoComplete = false;

      _ensureEpisodeInLiveProgress(seasonNumber, episodeNumber, episode.title);
      if (_liveSeriesProgress != null) {
        _liveSeriesProgress = [..._liveSeriesProgress!];
        _progressUpdateCounter++;
      }
    });

    ref
        .read(currentPlayingContentProvider.notifier)
        .state = CurrentPlayingContent(
      contentId: widget.contentItem.id,
      seasonNumber: seasonNumber,
      episodeNumber: episodeNumber,
    );
  }

  void _saveCurrentProgress(
    ContentDetails details,
    String serverId,
    String serverName, {
    bool immediate = false,
  }) {
    final videoPlayerState = _videoPlayerKey.currentState;
    if (videoPlayerState == null) return;

    final player = videoPlayerState.player;
    final videoController = videoPlayerState.videoController;

    if (player == null || videoController == null) return;

    final currentTime = player.state.position.inSeconds.toDouble();
    final duration = player.state.duration.inSeconds.toDouble();

    if (duration <= 0) return;

    _handleProgressUpdate(
      details,
      serverId,
      serverName,
      currentTime,
      duration,
      immediate: immediate,
    );
  }

  void _handleProgressUpdate(
    ContentDetails details,
    String serverId,
    String serverName,
    double currentTime,
    double duration, {
    bool immediate = false,
  }) {
    if (!immediate) {
      final now = DateTime.now();
      if (_lastProgressUpdate != null &&
          now.difference(_lastProgressUpdate!).inSeconds < 30) {
        return;
      }
      _lastProgressUpdate = now;
    } else {
      _lastProgressUpdate = DateTime.now();
    }

    final percentage = duration > 0 ? (currentTime / duration) * 100 : 0.0;
    final threshold = ref
        .read(videoPlaybackSettingsProvider)
        .autoCompleteThreshold;

    String posterUrl = details.posterUrl;
    final isOffline = ref.read(offlineModeProvider);
    if (isOffline) {
      final downloadedContent = ref.read(
        downloadedContentItemProvider((
          contentId: widget.contentItem.id,
          seasonNumber: _currentSeasonNumber,
          episodeNumber: _currentEpisodeNumber,
        )),
      );
      if (downloadedContent != null &&
          downloadedContent.localPosterPath != null &&
          downloadedContent.localPosterPath!.isNotEmpty) {
        posterUrl = downloadedContent.localPosterPath!;
      }
    }

    ref
        .read(watchHistoryNotifierProvider.notifier)
        .updateProgress(
          ftpServerId: serverId,
          serverName: serverName,
          serverType: widget.contentItem.serverType,
          contentType: details.contentType,
          contentId: widget.contentItem.id,
          contentTitle: details.title,
          currentTime: currentTime,
          duration: duration,
          seasonNumber: _currentSeasonNumber,
          episodeNumber: _currentEpisodeNumber,
          episodeId: _currentEpisodeId,
          episodeTitle: _currentEpisodeTitle,
          metadata: {
            'serverName': widget.contentItem.serverName,
            'posterUrl': posterUrl,
            'year': details.year,
            'quality': details.quality,
          },
          immediate: immediate,
        );

    if (_currentSeasonNumber != null &&
        _currentEpisodeNumber != null &&
        _liveSeriesProgress != null) {
      try {
        final seasonIndex = _liveSeriesProgress!.indexWhere(
          (s) => s.seasonNumber == _currentSeasonNumber,
        );
        if (seasonIndex != -1) {
          final season = _liveSeriesProgress![seasonIndex];
          final episodeIndex = season.episodes.indexWhere(
            (e) => e.episodeNumber == _currentEpisodeNumber,
          );
          if (episodeIndex != -1) {
            final updatedProgress = ProgressInfo(
              currentTime: currentTime,
              duration: duration,
              percentage: percentage,
            );

            season.episodes[episodeIndex] = EpisodeProgress(
              episodeNumber: season.episodes[episodeIndex].episodeNumber,
              episodeId: season.episodes[episodeIndex].episodeId,
              episodeTitle: season.episodes[episodeIndex].episodeTitle,
              status: season.episodes[episodeIndex].status,
              progress: updatedProgress,
              lastWatchedAt: season.episodes[episodeIndex].lastWatchedAt,
            );

            setState(() {
              _liveSeriesProgress = [..._liveSeriesProgress!];
              _progressUpdateCounter++;
            });
          }
        }
      } catch (e) {
        _logger.e(
          '[_handleProgressUpdate] Error updating series progress: $e',
          error: e,
        );
      }
    } else {
      setState(() {
        _progressUpdateCounter++;
      });
    }

    _checkAutoComplete(details, serverId, percentage, threshold);
  }

  Future<void> _checkAutoComplete(
    ContentDetails details,
    String serverId,
    double currentPercentage,
    int threshold,
  ) async {
    if (_hasTriggeredAutoComplete) return;

    final storage = ref.read(watchHistoryStorageProvider);
    final watchHistory = await storage.getWatchHistory(
      ftpServerId: serverId,
      contentId: widget.contentItem.id,
    );

    if (watchHistory == null || watchHistory.status != WatchStatus.watching) {
      return;
    }

    final isSeries =
        details.isSeries &&
        details.seasons != null &&
        details.seasons!.isNotEmpty;

    if (isSeries) {
      _checkSeriesAutoComplete(
        details,
        serverId,
        watchHistory,
        currentPercentage,
        threshold,
      );
    } else {
      if (currentPercentage >= threshold) {
        _hasTriggeredAutoComplete = true;
        await _markContentAsComplete(serverId);
      }
    }
  }

  Future<void> _checkSeriesAutoComplete(
    ContentDetails details,
    String serverId,
    WatchHistory watchHistory,
    double currentPercentage,
    int threshold,
  ) async {
    if (details.seasons == null || details.seasons!.isEmpty) return;

    final seasons = details.seasons!;
    final lastSeason = seasons.last;
    final lastSeasonNumber = _extractSeasonNumber(lastSeason.seasonName);
    final lastEpisodeNumber = lastSeason.episodes.length;

    final isLastEpisode =
        _currentSeasonNumber == lastSeasonNumber &&
        _currentEpisodeNumber == lastEpisodeNumber;

    if (!isLastEpisode) return;

    if (currentPercentage < threshold) return;

    final seriesProgress = watchHistory.seriesProgress;
    if (seriesProgress == null) return;

    for (final season in seasons) {
      final seasonNumber = _extractSeasonNumber(season.seasonName);
      final seasonProgress = seriesProgress
          .where((s) => s.seasonNumber == seasonNumber)
          .firstOrNull;

      if (seasonProgress == null) return;

      for (int i = 0; i < season.episodes.length; i++) {
        final episodeNumber = i + 1;
        final isCurrentEpisode =
            seasonNumber == _currentSeasonNumber &&
            episodeNumber == _currentEpisodeNumber;

        if (isCurrentEpisode) {
          if (currentPercentage < threshold) return;
        } else {
          final episodeProgress = seasonProgress.episodes
              .where((e) => e.episodeNumber == episodeNumber)
              .firstOrNull;

          if (episodeProgress == null ||
              episodeProgress.progress.percentage < threshold) {
            return;
          }
        }
      }
    }

    _hasTriggeredAutoComplete = true;
    await _markContentAsComplete(serverId);
  }

  Future<void> _markContentAsComplete(String serverId) async {
    try {
      await ref
          .read(watchHistoryNotifierProvider.notifier)
          .changeStatus(serverId, widget.contentItem.id, WatchStatus.completed);

      ref.invalidate(
        contentWatchHistoryProvider((
          ftpServerId: serverId,
          contentId: widget.contentItem.id,
        )),
      );

      if (mounted) {
        AppSnackbars.showSuccess(context, 'Marked as completed');
      }
    } catch (e) {
      _logger.e('Error marking content as complete: $e', error: e);
    }
  }
}

class _VideoPlayerWidgetWrapper extends StatefulWidget {
  const _VideoPlayerWidgetWrapper({
    required this.videoUrl,
    this.autoPlay = true,
    this.initialPosition,
    this.receivedPlayer,
    this.receivedController,
    this.showEpisodeControls = false,
    this.canGoToPreviousEpisode = false,
    this.canGoToNextEpisode = false,
    this.onPreviousEpisode,
    this.onNextEpisode,
    this.onFullscreenChanged,
    this.onProgressUpdate,
    this.onRequestImmediateSave,
    this.pipDragProgress = 0.0,
    super.key,
  });

  final String videoUrl;
  final bool autoPlay;
  final Duration? initialPosition;
  final Player? receivedPlayer;
  final VideoController? receivedController;
  final bool showEpisodeControls;
  final bool canGoToPreviousEpisode;
  final bool canGoToNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
  final double pipDragProgress;
  final void Function(bool)? onFullscreenChanged;
  final void Function(double currentTime, double duration)? onProgressUpdate;
  final void Function()? onRequestImmediateSave;

  @override
  State<_VideoPlayerWidgetWrapper> createState() =>
      _VideoPlayerWidgetWrapperState();
}

class _VideoPlayerWidgetWrapperState extends State<_VideoPlayerWidgetWrapper> {
  bool _ownershipTransferred = false;
  Player? _receivedPlayer;
  VideoController? _receivedController;
  String? _currentVideoUrl;
  final GlobalKey<State<VideoPlayerWidget>> _videoPlayerWidgetKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _receivedPlayer = widget.receivedPlayer;
    _receivedController = widget.receivedController;
    _currentVideoUrl = widget.videoUrl;
  }

  @override
  void didUpdateWidget(_VideoPlayerWidgetWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.videoUrl != oldWidget.videoUrl &&
        widget.videoUrl != _currentVideoUrl) {
      _currentVideoUrl = widget.videoUrl;
      _receivedPlayer = null;
      _receivedController = null;
      _ownershipTransferred = false;
      setState(() {});
    }
  }

  Player? get player {
    if (_ownershipTransferred) {
      return _receivedPlayer;
    }
    final state = _videoPlayerWidgetKey.currentState;
    if (state != null &&
        state.runtimeType.toString() == '_VideoPlayerWidgetState') {
      return (state as dynamic).player;
    }
    return null;
  }

  VideoController? get videoController {
    if (_ownershipTransferred) {
      return _receivedController;
    }
    final state = _videoPlayerWidgetKey.currentState;
    if (state != null &&
        state.runtimeType.toString() == '_VideoPlayerWidgetState') {
      return (state as dynamic).videoController;
    }
    return null;
  }

  Duration get currentPosition {
    final state = _videoPlayerWidgetKey.currentState;
    if (state != null &&
        state.runtimeType.toString() == '_VideoPlayerWidgetState') {
      return (state as dynamic).currentPosition as Duration;
    }
    return Duration.zero;
  }

  void transferOwnership() {
    setState(() {
      _ownershipTransferred = true;
    });

    final state = _videoPlayerWidgetKey.currentState;
    if (state != null &&
        state.runtimeType.toString() == '_VideoPlayerWidgetState') {
      (state as dynamic).transferOwnership();
    }
  }

  void receiveOwnership(Player player, VideoController controller) {
    setState(() {
      _receivedPlayer = player;
      _receivedController = controller;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_ownershipTransferred) {
      return Container(
        width: double.infinity,
        height: 250,
        color: AppColors.black,
      );
    }

    final forceHideControls = widget.pipDragProgress > 0.05;

    if (_receivedPlayer != null && _receivedController != null) {
      return VideoPlayerWidget.fromExisting(
        key: _videoPlayerWidgetKey,
        player: _receivedPlayer!,
        videoController: _receivedController!,
        showEpisodeControls: widget.showEpisodeControls,
        canGoToPreviousEpisode: widget.canGoToPreviousEpisode,
        canGoToNextEpisode: widget.canGoToNextEpisode,
        onPreviousEpisode: widget.onPreviousEpisode,
        onNextEpisode: widget.onNextEpisode,
        onFullscreenChanged: widget.onFullscreenChanged,
        onProgressUpdate: widget.onProgressUpdate,
        onRequestImmediateSave: widget.onRequestImmediateSave,
        forceHideControls: forceHideControls,
      );
    }

    return VideoPlayerWidget(
      key: _videoPlayerWidgetKey,
      videoUrl: widget.videoUrl,
      autoPlay: widget.autoPlay,
      initialPosition: widget.initialPosition,
      showEpisodeControls: widget.showEpisodeControls,
      canGoToPreviousEpisode: widget.canGoToPreviousEpisode,
      canGoToNextEpisode: widget.canGoToNextEpisode,
      onPreviousEpisode: widget.onPreviousEpisode,
      onNextEpisode: widget.onNextEpisode,
      onFullscreenChanged: widget.onFullscreenChanged,
      onProgressUpdate: widget.onProgressUpdate,
      onRequestImmediateSave: widget.onRequestImmediateSave,
      forceHideControls: forceHideControls,
    );
  }
}

class _EpisodeNavTarget {
  const _EpisodeNavTarget({
    required this.season,
    required this.seasonNumber,
    required this.episode,
    required this.episodeNumber,
  });

  final Season season;
  final int seasonNumber;
  final Episode episode;
  final int episodeNumber;
}

class _EpisodeNavigationConfig {
  const _EpisodeNavigationConfig({
    required this.showEpisodeControls,
    required this.canGoToPreviousEpisode,
    required this.canGoToNextEpisode,
    required this.onPreviousEpisode,
    required this.onNextEpisode,
  });

  final bool showEpisodeControls;
  final bool canGoToPreviousEpisode;
  final bool canGoToNextEpisode;
  final VoidCallback? onPreviousEpisode;
  final VoidCallback? onNextEpisode;
}
