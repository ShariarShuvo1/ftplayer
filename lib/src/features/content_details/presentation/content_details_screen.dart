import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:logger/logger.dart';

import '../../../app/theme/app_colors.dart';
import '../../../state/content/content_details_provider.dart';
import '../../../state/pip/pip_provider.dart';
import '../../home/data/home_models.dart';
import '../data/content_details_models.dart';
import 'widgets/video_player_widget.dart';

final _logger = Logger();

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
  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _activatedPipFromHere = false;
  Player? _receivedPlayer;
  VideoController? _receivedVideoController;
  bool _isVideoPlayerFullscreen = false;
  final GlobalKey<_VideoPlayerWidgetWrapperState> _videoPlayerKey = GlobalKey();

  @override
  void initState() {
    super.initState();

    final pipState = ref.read(pipProvider);
    if (!_activatedPipFromHere &&
        pipState.isActive &&
        pipState.player != null &&
        pipState.videoController != null &&
        pipState.contentItemJson != null) {
      try {
        final pipContentItem = ContentItem.fromJson(pipState.contentItemJson!);
        if (pipContentItem.id == widget.contentItem.id) {
          _logger.d('Receiving player from PiP - same content');
          _receivedPlayer = pipState.player;
          _receivedVideoController = pipState.videoController;

          Future.microtask(() {
            ref.read(pipProvider.notifier).deactivatePip(disposePlayer: false);
          });
        } else {
          _logger.d('Closing PiP - different content');
          Future.microtask(() {
            ref.read(pipProvider.notifier).deactivatePip(disposePlayer: true);
          });
        }
      } catch (e) {
        _logger.e('Error checking PiP content: $e');
      }
    }
  }

  void _notifyPlayerReceived() {
    if (_receivedPlayer != null && _receivedVideoController != null) {
      final videoPlayerState = _videoPlayerKey.currentState;
      if (videoPlayerState != null) {
        _logger.d('Notifying video player of received ownership');
        videoPlayerState.receiveOwnership(
          _receivedPlayer!,
          _receivedVideoController!,
        );
        _receivedPlayer = null;
        _receivedVideoController = null;
      }
    }
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
    final threshold = MediaQuery.of(context).size.height * 0.3;

    if (_dragOffset > threshold) {
      _activatePipMode();
    } else {
      setState(() {
        _dragOffset = 0.0;
        _isDragging = false;
      });
    }
  }

  void _activatePipMode() {
    _logger.d('Attempting to activate PiP mode');
    final videoPlayerState = _videoPlayerKey.currentState;

    if (videoPlayerState != null &&
        videoPlayerState.player != null &&
        videoPlayerState.videoController != null) {
      final detailsAsync = ref.read(
        contentDetailsProvider((
          contentId: widget.contentItem.id,
          serverName: widget.contentItem.serverName,
          serverType: widget.contentItem.serverType,
          initialData: null,
        )),
      );

      final title = detailsAsync.value?.title ?? widget.contentItem.title;
      final videoUrl = _currentVideoUrl ?? detailsAsync.value?.videoUrl ?? '';

      _logger.d('Activating PiP: $title');

      ref
          .read(pipProvider.notifier)
          .activatePip(
            player: videoPlayerState.player!,
            videoController: videoPlayerState.videoController!,
            videoUrl: videoUrl,
            videoTitle: title,
            contentItemJson: widget.contentItem.toJson(),
          );

      videoPlayerState.transferOwnership();

      setState(() {
        _activatedPipFromHere = true;
      });

      Navigator.of(context).pop();
    } else {
      _logger.w('Cannot activate PiP - missing player or controller');
      setState(() {
        _dragOffset = 0.0;
        _isDragging = false;
      });
    }
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

    return Scaffold(
      backgroundColor: AppColors.black,
      body: Stack(
        children: [
          detailsAsync.when(
            data: (details) => GestureDetector(
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
          if (_isDragging && _dragOffset > 100)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.picture_in_picture_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _dragOffset > MediaQuery.of(context).size.height * 0.3
                            ? 'Release for PiP mode'
                            : 'Drag down for PiP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(ContentDetails details) {
    final videoUrl = _currentVideoUrl ?? details.videoUrl;

    if (details.isSeries && details.seasons != null) {
      _tabController ??= TabController(
        length: details.seasons!.length,
        vsync: this,
      );
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
                  return _VideoPlayerWidgetWrapper(
                    key: _videoPlayerKey,
                    videoUrl: videoUrl,
                    autoPlay: true,
                    receivedPlayer: _receivedPlayer,
                    receivedController: _receivedVideoController,
                    onFullscreenChanged: (isFullscreen) {
                      setState(() {
                        _isVideoPlayerFullscreen = isFullscreen;
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
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.title,
                        style: const TextStyle(
                          color: AppColors.textHigh,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (details.year != null) ...[
                            Text(
                              details.year!,
                              style: const TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (details.quality != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                details.quality!,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (details.watchTime != null) ...[
                            const Text(
                              '•',
                              style: TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              details.watchTime!,
                              style: const TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          if (details.rating != null) ...[
                            const SizedBox(width: 8),
                            const Text(
                              '•',
                              style: TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.star,
                              color: AppColors.warning,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              details.rating!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.textMid,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (details.description != null &&
                          details.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(
                          details.description!,
                          style: const TextStyle(
                            color: AppColors.textMid,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                      if (details.tags != null && details.tags!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: details.tags!
                              .split(',')
                              .where((tag) => tag.trim().isNotEmpty)
                              .map(
                                (tag) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    tag.trim(),
                                    style: const TextStyle(
                                      color: AppColors.textLow,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (details.isSeries && details.seasons != null) ...[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _SeasonTabBarDelegate(
                    tabController: _tabController!,
                    seasons: details.seasons!,
                  ),
                ),
                SliverFillRemaining(
                  child: TabBarView(
                    controller: _tabController,
                    children: details.seasons!
                        .map((season) => _buildEpisodeList(season))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeList(Season season) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: season.episodes.length,
      itemBuilder: (context, index) {
        final episode = season.episodes[index];
        final isPlaying = _currentVideoUrl == episode.link;
        final episodeNumber = index + 1;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isPlaying
                ? AppColors.primary.withValues(alpha: 0.1)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPlaying
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _currentVideoUrl = episode.link;
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? AppColors.primary
                            : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: isPlaying
                            ? const Icon(
                                Icons.pause,
                                color: AppColors.black,
                                size: 24,
                              )
                            : Text(
                                episodeNumber.toString(),
                                style: const TextStyle(
                                  color: AppColors.textMid,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            episode.title,
                            style: TextStyle(
                              color: isPlaying
                                  ? AppColors.primary
                                  : AppColors.textHigh,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isPlaying) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.play_circle_filled,
                                  size: 14,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Now Playing',
                                  style: TextStyle(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.8,
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      isPlaying ? Icons.volume_up : Icons.play_circle_outline,
                      color: isPlaying ? AppColors.primary : AppColors.textLow,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SeasonTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SeasonTabBarDelegate({required this.tabController, required this.seasons});

  final TabController tabController;
  final List<Season> seasons;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.black,
        border: Border(
          bottom: BorderSide(color: AppColors.outline, width: 0.5),
        ),
      ),
      child: TabBar(
        controller: tabController,
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
        tabs: seasons
            .map(
              (season) => Tab(
                height: 32,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  child: Text(season.seasonName),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}

class _VideoPlayerWidgetWrapper extends StatefulWidget {
  const _VideoPlayerWidgetWrapper({
    required this.videoUrl,
    this.autoPlay = true,
    this.receivedPlayer,
    this.receivedController,
    this.onFullscreenChanged,
    super.key,
  });

  final String videoUrl;
  final bool autoPlay;
  final Player? receivedPlayer;
  final VideoController? receivedController;
  final void Function(bool)? onFullscreenChanged;

  @override
  State<_VideoPlayerWidgetWrapper> createState() =>
      _VideoPlayerWidgetWrapperState();
}

class _VideoPlayerWidgetWrapperState extends State<_VideoPlayerWidgetWrapper> {
  final GlobalKey _playerKey = GlobalKey();
  bool _ownershipTransferred = false;
  Player? _receivedPlayer;
  VideoController? _receivedController;

  @override
  void initState() {
    super.initState();
    _receivedPlayer = widget.receivedPlayer;
    _receivedController = widget.receivedController;
  }

  Player? get player {
    if (_receivedPlayer != null) return _receivedPlayer;

    final state = _playerKey.currentState;
    if (state != null) {
      try {
        return (state as dynamic).player as Player?;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  VideoController? get videoController {
    if (_receivedController != null) return _receivedController;

    final state = _playerKey.currentState;
    if (state != null) {
      try {
        return (state as dynamic).videoController as VideoController?;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  void transferOwnership() {
    final state = _playerKey.currentState;
    if (state != null) {
      try {
        (state as dynamic).transferOwnership();
        setState(() {
          _ownershipTransferred = true;
        });
      } catch (e) {
        setState(() {
          _ownershipTransferred = false;
        });
      }
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
        key: _playerKey,
        player: _receivedPlayer!,
        videoController: _receivedController!,
        onFullscreenChanged: widget.onFullscreenChanged,
      );
    }

    return VideoPlayerWidget(
      key: _playerKey,
      videoUrl: widget.videoUrl,
      autoPlay: widget.autoPlay,
      onFullscreenChanged: widget.onFullscreenChanged,
    );
  }
}
