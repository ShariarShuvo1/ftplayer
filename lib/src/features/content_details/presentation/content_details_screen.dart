import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../../../app/theme/app_colors.dart';
import '../../../state/content/content_details_provider.dart';
import '../../../state/pip/pip_provider.dart';
import '../../../state/ftp/working_ftp_servers_provider.dart';
import '../../../state/watch_history/watch_history_provider.dart';
import '../../home/data/home_models.dart';
import '../data/content_details_models.dart';
import 'widgets/video_player_widget.dart';
import 'widgets/watch_status_dropdown.dart';
import 'widgets/content_details_section.dart';
import 'widgets/seasons_section.dart';
import 'widgets/comments_section.dart';

class ContentDetailsScreen extends ConsumerStatefulWidget {
  const ContentDetailsScreen({required this.contentItem, super.key});

  static const path = '/content-details';

  final ContentItem contentItem;

  @override
  ConsumerState<ContentDetailsScreen> createState() =>
      _ContentDetailsScreenState();
}

class _ContentDetailsScreenState extends ConsumerState<ContentDetailsScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  String? _currentVideoUrl;
  int? _currentSeasonNumber;
  int? _currentEpisodeNumber;
  String? _currentEpisodeId;
  String? _currentEpisodeTitle;
  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _activatedPipFromHere = false;
  Player? _receivedPlayer;
  VideoController? _receivedVideoController;
  bool _isVideoPlayerFullscreen = false;
  Duration? _initialPosition;
  final GlobalKey<_VideoPlayerWidgetWrapperState> _videoPlayerKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    if (widget.contentItem.initialProgress != null) {
      _initialPosition = widget.contentItem.initialProgress;
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

          // Restore episode state for series
          _currentVideoUrl = pipState.currentVideoUrl;
          _currentSeasonNumber = pipState.currentSeasonNumber;
          _currentEpisodeNumber = pipState.currentEpisodeNumber;
          _currentEpisodeId = pipState.currentEpisodeId;
          _currentEpisodeTitle = pipState.currentEpisodeTitle;

          Future.microtask(() {
            ref.read(pipProvider.notifier).deactivatePip(disposePlayer: false);
          });
        } else {
          Future.microtask(() {
            ref.read(pipProvider.notifier).deactivatePip(disposePlayer: true);
          });
        }
      } catch (e) {
        // Ignore errors when processing PiP state
      }
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

        setState(() {
          _currentVideoUrl = episode.link;
          _currentEpisodeTitle = episode.title;
        });
      }
    }
  }

  int _extractSeasonNumber(String seasonName) {
    final regex = RegExp(r'\d+');
    final match = regex.firstMatch(seasonName);
    return match != null ? int.parse(match.group(0)!) : 0;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _isDragging = true;
      _dragOffset += details.delta.dy;
      _dragOffset = _dragOffset.clamp(0.0, double.infinity);
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    final threshold = MediaQuery.of(context).size.height * 0.5;

    if (_dragOffset > threshold) {
      _activatePipMode();
    } else {
      setState(() {
        _dragOffset = 0.0;
        _isDragging = false;
      });
    }
  }

  Widget _buildDragProgressIndicator() {
    final screenHeight = MediaQuery.of(context).size.height;
    final threshold = screenHeight * 0.5;
    final progress = (_dragOffset / threshold).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary.withValues(alpha: 0.95),
                AppColors.primary.withValues(alpha: 0.85),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.5),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CustomPaint(
                  painter: _CircleProgressPainter(
                    progress: progress,
                    strokeWidth: 2.5,
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    progressColor: Colors.white,
                  ),
                ),
              ),
              Icon(Icons.arrow_downward, color: Colors.white, size: 20),
            ],
          ),
        ),
      ],
    );
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
      final snapToLeft = _dragOffset < screenWidth / 2;
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

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(
      contentDetailsProvider((
        contentId: widget.contentItem.id,
        serverName: widget.contentItem.serverName,
        serverType: widget.contentItem.serverType,
        initialData: null,
      )),
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: detailsAsync.when(
          data: (details) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _selectInitialEpisode(details);
            });
            return Stack(
              children: [
                GestureDetector(
                  onVerticalDragUpdate: _handleVerticalDragUpdate,
                  onVerticalDragEnd: _handleVerticalDragEnd,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    transform: Matrix4.translationValues(0, _dragOffset, 0),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _isDragging ? 0.9 - (_dragOffset / 1000) : 1.0,
                      child: _buildContent(details),
                    ),
                  ),
                ),
                if (_isDragging && _dragOffset > 0)
                  Positioned(
                    top: 60.0,
                    left: 0,
                    right: 0,
                    child: GestureDetector(
                      onVerticalDragUpdate: (_) {},
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(child: _buildDragProgressIndicator()),
                          const SizedBox(height: 16),
                          Center(
                            child: AnimatedOpacity(
                              opacity:
                                  _dragOffset >
                                      MediaQuery.of(context).size.height * 0.5
                                  ? 1.0
                                  : 0.6,
                              duration: const Duration(milliseconds: 150),
                              child: Text(
                                _dragOffset >
                                        MediaQuery.of(context).size.height * 0.5
                                    ? 'Release to activate PiP'
                                    : 'Keep dragging',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
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
    );
  }

  Widget _buildContent(ContentDetails details) {
    final videoUrl = _currentVideoUrl ?? details.videoUrl;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentVideoUrl == null && videoUrl != null && videoUrl.isNotEmpty) {
        setState(() {
          _currentVideoUrl = videoUrl;
        });
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

    return Column(
      children: [
        if (videoUrl != null && videoUrl.isNotEmpty)
          Stack(
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
                        .where((s) => s.name == widget.contentItem.serverName)
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
                            final matchingEpisode = season.episodes.where((ep) {
                              final episodeNum = int.tryParse(
                                ep.title.split('E').last.split(' ').first,
                              );
                              return episodeNum == _currentEpisodeNumber;
                            }).firstOrNull;

                            if (matchingEpisode != null) {
                              if (watchHistory.seriesProgress != null &&
                                  watchHistory.seriesProgress!.isNotEmpty) {
                                try {
                                  final backendSeason = watchHistory
                                      .seriesProgress!
                                      .firstWhere(
                                        (s) =>
                                            s.seasonNumber ==
                                            _currentSeasonNumber,
                                      );

                                  final backendEpisode = backendSeason.episodes
                                      .firstWhere(
                                        (e) =>
                                            e.episodeNumber ==
                                            _currentEpisodeNumber,
                                      );

                                  if (backendEpisode.progress.currentTime > 0) {
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
                          seconds: watchHistory.progress!.currentTime.toInt(),
                        );
                      }

                      if (position != null) {
                        resolvedInitialPosition = position;
                      }
                    }
                  }

                  return _VideoPlayerWidgetWrapper(
                    key: _videoPlayerKey,
                    videoUrl: videoUrl,
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
                              (s) => s.name == widget.contentItem.serverName,
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
                child: SafeArea(
                  child: _isVideoPlayerFullscreen
                      ? const SizedBox.shrink()
                      : IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                ),
              ),
            ],
          )
        else
          Container(
            width: double.infinity,
            height: 250,
            color: AppColors.black,
            child: details.posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: details.posterUrl,
                    fit: BoxFit.cover,
                  )
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
                child: ContentDetailsSection(
                  details: details,
                  onWatchStatusDropdown: _buildWatchStatusDropdown,
                ),
              ),
              if (details.isSeries && details.seasons != null)
                SliverToBoxAdapter(
                  child: SeasonsSection(
                    details: details,
                    tabController: _tabController!,
                    currentVideoUrl: _currentVideoUrl,
                    onEpisodeTap: _handleEpisodeTap,
                  ),
                ),
              SliverToBoxAdapter(
                child: Builder(
                  builder: (context) {
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
                        return CommentsSection(
                          ftpServerId: server.id,
                          serverType: server.serverType,
                          contentType: details.contentType,
                          contentId: widget.contentItem.id,
                          contentTitle: details.title,
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

  void _handleEpisodeTap(
    Season season,
    int seasonNumber,
    int episodeNumber,
    Episode episode,
  ) {
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
      final watchHistoryAsync = ref.read(
        contentWatchHistoryProvider((
          ftpServerId: serverId,
          contentId: widget.contentItem.id,
        )),
      );

      watchHistoryAsync.whenData((watchHistory) {
        if (watchHistory != null) {
          for (final season in watchHistory.seriesProgress ?? []) {
            final ep = season.episodes.firstWhere(
              (e) => e.episodeId == newEpisodeId,
              orElse: () => season.episodes.first,
            );
            if (ep.episodeId == newEpisodeId) {
              newPosition = Duration(seconds: ep.progress.currentTime.toInt());
              break;
            }
          }
        }
      });
    }

    setState(() {
      _currentVideoUrl = episode.link;
      _currentSeasonNumber = seasonNumber;
      _currentEpisodeNumber = episodeNumber;
      _currentEpisodeId = newEpisodeId;
      _currentEpisodeTitle = episode.title;
      _initialPosition = newPosition;
    });
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

class _CircleProgressPainter extends CustomPainter {
  _CircleProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    const pi = 3.14159265359;
    final sweepAngle = progress * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_CircleProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
