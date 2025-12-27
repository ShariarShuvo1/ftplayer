import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:logger/logger.dart';
import '../../../app/theme/app_colors.dart';
import '../../../state/content/content_details_provider.dart';
import '../../../state/content/current_playing_content_provider.dart';
import '../../../state/content/playback_state_provider.dart';
import '../../../state/pip/pip_provider.dart';
import '../../../state/pip/pip_state.dart';
import '../../../state/ftp/working_ftp_servers_provider.dart';
import '../../../state/watch_history/watch_history_provider.dart';
import '../../../state/connectivity/connectivity_provider.dart';
import '../../../state/downloads/download_provider.dart';
import '../../home/data/home_models.dart';
import '../data/content_details_models.dart';
import '../../watch_history/data/watch_history_models.dart';
import 'widgets/video_player_widget.dart';
import 'widgets/watch_status_dropdown.dart';
import 'widgets/content_details_section.dart';
import 'widgets/seasons_section.dart';
import 'widgets/offline_seasons_section.dart';
import 'widgets/comments_section.dart';
import 'widgets/download_button.dart';

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
  bool _hasAppliedInitialPosition = false;
  List<SeasonProgress>? _liveSeriesProgress;
  int _progressUpdateCounter = 0;
  final GlobalKey<_VideoPlayerWidgetWrapperState> _videoPlayerKey = GlobalKey();
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

    final playbackCache = ref.read(playbackStateProvider);
    if (playbackCache != null &&
        playbackCache.contentId == widget.contentItem.id) {
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

  void _selectInitialEpisode(ContentDetails details) {
    if (_currentVideoUrl == null &&
        widget.contentItem.initialSeasonNumber != null &&
        widget.contentItem.initialEpisodeNumber != null &&
        details.isSeries &&
        details.seasons != null) {
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
          } else {}
        }

        setState(() {
          _currentVideoUrl = resolvedUrl;
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
    } else {
      ref
          .read(currentPlayingContentProvider.notifier)
          .state = CurrentPlayingContent(
        contentId: widget.contentItem.id,
        seasonNumber: null,
        episodeNumber: null,
      );
    }
  }

  int _extractSeasonNumber(String seasonName) {
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(seasonName);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  Future<void> _fetchInitialPositionForMovie(String serverId) async {
    if (widget.contentItem.contentType != 'movie') return;
    if (_hasAppliedInitialPosition) return;

    try {
      final watchHistoryAsync = await ref.refresh(
        contentWatchHistoryProvider((
          ftpServerId: serverId,
          contentId: widget.contentItem.id,
        )).future,
      );

      if (watchHistoryAsync?.progress != null) {
        final currentTime = watchHistoryAsync!.progress!.currentTime;
        final duration = watchHistoryAsync.progress!.duration;

        if (duration > 0) {
          final percentage = (currentTime / duration) * 100;
          if (percentage >= 95) {
            _initialPosition = Duration.zero;
          } else if (currentTime > 5) {
            _initialPosition = Duration(seconds: currentTime.toInt());
          }
          _hasAppliedInitialPosition = true;
        }
      } else {}
    } catch (e) {
      _logger.e('Error fetching watch history for movie: $e');
    }
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
    final workingServersAsync = ref.read(workingFtpServersProvider);

    if (!workingServersAsync.hasValue) {
      return null;
    }

    final servers = workingServersAsync.value!;
    final server = servers
        .where((s) => s.name == widget.contentItem.serverName)
        .firstOrNull;

    return server?.id;
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
    try {
      ref.read(currentPlayingContentProvider.notifier).state = null;
    } catch (_) {
      // Ignore if provider is already disposed
    }
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

      videoPlayerState.transferOwnership();

      setState(() {
        _activatedPipFromHere = true;
      });

      try {
        await videoPlayerState.player!.play();
      } catch (e) {
        // Ignore errors when playing video
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      _resetDragState();
    }
  }

  void _resetDragState() {
    setState(() {
      _dragOffset = 0.0;
      _isDragging = false;
    });
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
        final episodeNumber = episodeIndex + 1;

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
        } else {}

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
        return _buildErrorWidget(
          'Failed to load offline content',
          e.toString(),
        );
      }

      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, result) {},
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                if (_isDragging)
                  Positioned.fill(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 100),
                      opacity:
                          (1.0 - _getSwipeProgress(context)).clamp(0.0, 1.0) *
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
                          ? AppColors.surface.withValues(
                              alpha: (1.0 - _getSectionHideProgress(context))
                                  .clamp(0.0, 1.0),
                            )
                          : AppColors.surface,
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

    final detailsAsync = ref.watch(
      contentDetailsProvider((
        contentId: widget.contentItem.id,
        serverName: widget.contentItem.serverName,
        serverType: widget.contentItem.serverType,
        initialData: widget.contentItem.initialData,
      )),
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: detailsAsync.when(
            data: (details) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _selectInitialEpisode(details);
              });
              return Stack(
                children: [
                  if (_isDragging)
                    Positioned.fill(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 100),
                        opacity:
                            (1.0 - _getSwipeProgress(context)).clamp(0.0, 1.0) *
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
                            ? AppColors.surface.withValues(
                                alpha: (1.0 - _getSectionHideProgress(context))
                                    .clamp(0.0, 1.0),
                              )
                            : AppColors.surface,
                        child: _buildContent(details),
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
                    style: TextStyle(color: AppColors.textMid, fontSize: 16),
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

  Widget _buildOfflineContent(ContentDetails details) {
    if (details.isSeries &&
        details.seasons != null &&
        details.seasons!.isNotEmpty) {
      if (_currentVideoUrl == null) {
        final firstSeason = details.seasons!.first;
        if (firstSeason.episodes.isNotEmpty) {
          final firstEpisode = firstSeason.episodes.first;
          _currentVideoUrl = firstEpisode.link;
          _currentSeasonNumber ??= _extractSeasonNumber(firstSeason.seasonName);
          _currentEpisodeNumber ??= firstEpisode.episodeNumber ?? 1;
          _currentEpisodeId ??= firstEpisode.id;
          _currentEpisodeTitle ??= firstEpisode.title;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!details.isSeries && !_hasAppliedInitialPosition) {
        final workingServersAsync = ref.read(workingFtpServersProvider);
        final serverId = workingServersAsync.maybeWhen(
          data: (servers) => servers.isNotEmpty ? servers.first.id : null,
          orElse: () => null,
        );
        if (serverId != null) {
          _fetchInitialPositionForMovie(serverId).then((_) {
            if (mounted && _initialPosition != null) {
              setState(() {});
            }
          });
        }
      }

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
        if (widget.contentItem.initialSeasonNumber != null &&
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

                        return _VideoPlayerWidgetWrapper(
                          key: _videoPlayerKey,
                          videoUrl: _resolveVideoUrl(ref, videoUrl),
                          autoPlay: true,
                          initialPosition: resolvedInitialPosition,
                          receivedPlayer: _receivedPlayer,
                          receivedController: _receivedVideoController,
                          onProgressUpdate: (currentTime, duration) {
                            _initialPosition = Duration(
                              seconds: currentTime.toInt(),
                            );
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
                    onWatchStatusDropdown: (_) => const SizedBox.shrink(),
                    onDownloadButton: null,
                  ),
                ),
                if (details.isSeries && details.seasons != null)
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: sectionOpacity,
                    child: OfflineSeasonsSection(
                      seasons: details.seasons!,
                      currentSeasonNumber: _currentSeasonNumber,
                      currentEpisodeNumber: _currentEpisodeNumber,
                      currentEpisodeId: _currentEpisodeId,
                      contentItem: widget.contentItem,
                      onEpisodeSelected: (season, episode) {
                        final seasonNum = _extractSeasonNumber(
                          season.seasonName,
                        );
                        final episodeNum = episode.episodeNumber ?? 1;
                        setState(() {
                          _currentVideoUrl = episode.link;
                          _currentSeasonNumber = seasonNum;
                          _currentEpisodeNumber = episodeNum;
                          _currentEpisodeId = episode.id;
                          _currentEpisodeTitle = episode.title;
                        });
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!details.isSeries && !_hasAppliedInitialPosition) {
        final workingServersAsync = ref.read(workingFtpServersProvider);
        final serverId = workingServersAsync.maybeWhen(
          data: (servers) => servers.isNotEmpty ? servers.first.id : null,
          orElse: () => null,
        );
        if (serverId != null) {
          _fetchInitialPositionForMovie(serverId).then((_) {
            if (mounted && _initialPosition != null) {
              setState(() {});
            }
          });
        }
      }

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
        if (widget.contentItem.initialSeasonNumber != null &&
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
          Transform.translate(
            offset: Offset(videoHorizontalOffset, 0),
            child: Transform.scale(
              scale: videoScale,
              alignment: Alignment.topCenter,
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
                                (s) => s.name == widget.contentItem.serverName,
                              )
                              .firstOrNull
                              ?.id,
                          orElse: () => null,
                        );

                        Duration? resolvedInitialPosition = _initialPosition;

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
                            Duration? position;

                            if (_currentSeasonNumber != null &&
                                _currentEpisodeNumber != null &&
                                details.isSeries &&
                                details.seasons != null &&
                                details.seasons!.isNotEmpty) {
                              final seasonIndex = details.seasons!.indexWhere(
                                (s) =>
                                    _extractSeasonNumber(s.seasonName) ==
                                    _currentSeasonNumber,
                              );

                              if (seasonIndex != -1) {
                                final season = details.seasons![seasonIndex];

                                if (season.episodes.isNotEmpty) {
                                  final matchingEpisode = season.episodes.where(
                                    (ep) {
                                      final episodeNum = int.tryParse(
                                        ep.title
                                            .split('E')
                                            .last
                                            .split(' ')
                                            .first,
                                      );
                                      return episodeNum ==
                                          _currentEpisodeNumber;
                                    },
                                  ).firstOrNull;

                                  if (matchingEpisode != null) {
                                    if (watchHistory.seriesProgress != null &&
                                        watchHistory
                                            .seriesProgress!
                                            .isNotEmpty) {
                                      try {
                                        final backendSeason = watchHistory
                                            .seriesProgress!
                                            .firstWhere(
                                              (s) =>
                                                  s.seasonNumber ==
                                                  _currentSeasonNumber,
                                            );

                                        final backendEpisode = backendSeason
                                            .episodes
                                            .firstWhere(
                                              (e) =>
                                                  e.episodeNumber ==
                                                  _currentEpisodeNumber,
                                            );

                                        if (backendEpisode
                                                .progress
                                                .currentTime >
                                            0) {
                                          position = Duration(
                                            seconds: backendEpisode
                                                .progress
                                                .currentTime
                                                .toInt(),
                                          );
                                        }
                                      } catch (e) {
                                        // Ignore errors when extracting episode progress
                                      }
                                    }
                                  }
                                }
                              }
                            }

                            if (position == null &&
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

                        return _VideoPlayerWidgetWrapper(
                          key: _videoPlayerKey,
                          videoUrl: _resolveVideoUrl(ref, videoUrl),
                          autoPlay: true,
                          initialPosition: resolvedInitialPosition,
                          receivedPlayer: _receivedPlayer,
                          receivedController: _receivedVideoController,
                          onFullscreenChanged: (isFullscreen) {
                            setState(() {
                              _isVideoPlayerFullscreen = isFullscreen;
                            });
                          },
                          onProgressUpdate: (currentTime, duration) {
                            final workingServersAsync = ref.read(
                              workingFtpServersProvider,
                            );
                            workingServersAsync.whenData((servers) {
                              final server = servers
                                  .where(
                                    (s) =>
                                        s.name == widget.contentItem.serverName,
                                  )
                                  .firstOrNull;
                              if (server != null) {
                                _handleProgressUpdate(
                                  details,
                                  server.id,
                                  currentTime,
                                  duration,
                                );
                              }
                            });
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
                          details: details,
                          tabController: _tabController!,
                          currentVideoUrl: _currentVideoUrl,
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
                          skipInitialAnimation:
                              _activatedPipFromHere || _receivedPlayer != null,
                          seriesProgress: _liveSeriesProgress ?? seriesProgress,
                          progressUpdateCounter: _progressUpdateCounter,
                        );
                      },
                    ),
                  ),
                ),
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
                    final isOffline = ref.watch(offlineModeProvider);
                    if (isOffline) return const SizedBox.shrink();
                    final workingServersAsync = ref.watch(
                      workingFtpServersProvider,
                    );
                    return workingServersAsync.when(
                      data: (servers) {
                        final server = servers
                            .where(
                              (s) => s.name == widget.contentItem.serverName,
                            )
                            .firstOrNull;
                        if (server == null) {
                          return const SizedBox.shrink();
                        }
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: sectionOpacity,
                          child: CommentsSection(
                            ftpServerId: server.id,
                            serverType: server.serverType,
                            contentType: details.contentType,
                            contentId: widget.contentItem.id,
                            contentTitle: details.title,
                            skipInitialAnimation:
                                _activatedPipFromHere ||
                                _receivedPlayer != null,
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    );
                  },
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
    final workingServersAsync = ref.read(workingFtpServersProvider);
    final serverId = workingServersAsync.maybeWhen(
      data: (servers) => servers
          .where((s) => s.name == widget.contentItem.serverName)
          .firstOrNull
          ?.id,
      orElse: () => null,
    );

    if (serverId != null) {
      final detailsAsync = ref.read(
        contentDetailsProvider((
          contentId: widget.contentItem.id,
          serverName: widget.contentItem.serverName,
          serverType: widget.contentItem.serverType,
          initialData: null,
        )),
      );

      detailsAsync.whenData((details) {
        _saveCurrentProgress(details, serverId);
      });
    }

    final newEpisodeId =
        '${widget.contentItem.id}_s${seasonNumber}_e$episodeNumber';

    Duration? newPosition;
    if (serverId != null) {
      newPosition = await _fetchInitialPositionForEpisode(
        serverId,
        seasonNumber,
        episodeNumber,
      );
    }

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
        } else {}
      }

      _currentVideoUrl = resolvedUrl;
      _currentSeasonNumber = seasonNumber;
      _currentEpisodeNumber = episodeNumber;
      _currentEpisodeId = newEpisodeId;
      _currentEpisodeTitle = episode.title;
      _initialPosition = newPosition;

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

  Widget _buildDownloadButton(ContentDetails details) {
    final workingServersAsync = ref.watch(workingFtpServersProvider);

    return workingServersAsync.when(
      data: (servers) {
        final server = servers
            .where((s) => s.name == widget.contentItem.serverName)
            .firstOrNull;

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
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildEpisodeDownloadButton(
    ContentDetails details,
    Season season,
    int seasonNumber,
    int episodeNumber,
    Episode episode,
  ) {
    final workingServersAsync = ref.watch(workingFtpServersProvider);

    return workingServersAsync.when(
      data: (servers) {
        final server = servers
            .where((s) => s.name == widget.contentItem.serverName)
            .firstOrNull;

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
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildWatchStatusDropdown(ContentDetails details) {
    final workingServersAsync = ref.watch(workingFtpServersProvider);

    return workingServersAsync.when(
      data: (servers) {
        final server = servers
            .where((s) => s.name == widget.contentItem.serverName)
            .firstOrNull;

        if (server == null) {
          return const SizedBox.shrink();
        }

        return WatchStatusDropdown(
          ftpServerId: server.id,
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
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  void _saveCurrentProgress(ContentDetails details, String serverId) {
    final videoPlayerState = _videoPlayerKey.currentState;
    if (videoPlayerState == null) return;

    final player = videoPlayerState.player;
    final videoController = videoPlayerState.videoController;

    if (player == null || videoController == null) return;

    final currentTime = player.state.position.inSeconds.toDouble();
    final duration = player.state.duration.inSeconds.toDouble();

    if (duration <= 0) return;

    _handleProgressUpdate(details, serverId, currentTime, duration);
  }

  void _handleProgressUpdate(
    ContentDetails details,
    String serverId,
    double currentTime,
    double duration,
  ) {
    ref
        .read(watchHistoryNotifierProvider.notifier)
        .updateProgress(
          ftpServerId: serverId,
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
            'posterUrl': details.posterUrl,
            'year': details.year,
            'quality': details.quality,
          },
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
              percentage: duration > 0 ? (currentTime / duration) * 100 : 0.0,
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
        // Silently ignore errors updating live series progress
      }
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
    this.onFullscreenChanged,
    this.onProgressUpdate,
    super.key,
  });

  final String videoUrl;
  final bool autoPlay;
  final Duration? initialPosition;
  final Player? receivedPlayer;
  final VideoController? receivedController;
  final void Function(bool)? onFullscreenChanged;
  final void Function(double currentTime, double duration)? onProgressUpdate;

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

    if (_receivedPlayer != null && _receivedController != null) {
      return VideoPlayerWidget.fromExisting(
        key: _videoPlayerWidgetKey,
        player: _receivedPlayer!,
        videoController: _receivedController!,
        onFullscreenChanged: widget.onFullscreenChanged,
        onProgressUpdate: widget.onProgressUpdate,
      );
    }

    return VideoPlayerWidget(
      key: _videoPlayerWidgetKey,
      videoUrl: widget.videoUrl,
      autoPlay: widget.autoPlay,
      initialPosition: widget.initialPosition,
      onFullscreenChanged: widget.onFullscreenChanged,
      onProgressUpdate: widget.onProgressUpdate,
    );
  }
}
