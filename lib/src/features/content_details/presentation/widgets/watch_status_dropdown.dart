import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../state/watch_history/watch_history_provider.dart';
import '../../../watch_history/data/watch_history_models.dart';

class WatchStatusDropdown extends ConsumerStatefulWidget {
  const WatchStatusDropdown({
    required this.ftpServerId,
    required this.serverType,
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
    this.metadata,
    super.key,
  });

  final String ftpServerId;
  final String serverType;
  final String contentType;
  final String contentId;
  final String contentTitle;
  final Map<String, dynamic>? metadata;

  @override
  ConsumerState<WatchStatusDropdown> createState() =>
      _WatchStatusDropdownState();
}

class _WatchStatusDropdownState extends ConsumerState<WatchStatusDropdown> {
  bool _isUpdating = false;
  bool _hasInitialized = false;

  @override
  Widget build(BuildContext context) {
    final watchHistoryAsync = ref.watch(
      contentWatchHistoryProvider((
        ftpServerId: widget.ftpServerId,
        contentId: widget.contentId,
      )),
    );

    return watchHistoryAsync.when(
      data: (watchHistory) {
        if (!_hasInitialized) {
          _hasInitialized = true;
          if (watchHistory == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _initializeWatchHistory();
            });
          }
        }

        final currentStatus = watchHistory?.status;
        final isDisabled = _isUpdating || watchHistory == null;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: DropdownButton<WatchStatus>(
            value: currentStatus,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: AppColors.surface,
            icon: _isUpdating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.arrow_drop_down, color: AppColors.textHigh),
            style: const TextStyle(color: AppColors.textHigh, fontSize: 14),
            items: WatchStatus.values.map((status) {
              return DropdownMenuItem(
                value: status,
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      size: 16,
                      color: _getStatusColor(status),
                    ),
                    const SizedBox(width: 8),
                    Text(status.label),
                  ],
                ),
              );
            }).toList(),
            onChanged: isDisabled
                ? null
                : (newStatus) {
                    if (newStatus != null && newStatus != currentStatus) {
                      _updateStatus(watchHistory, newStatus);
                    }
                  },
          ),
        );
      },
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
      error: (error, _) {
        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _initializeWatchHistory() async {
    setState(() {
      _isUpdating = true;
    });

    try {
      await ref
          .read(watchHistoryNotifierProvider.notifier)
          .updateStatus(
            ftpServerId: widget.ftpServerId,
            serverType: widget.serverType,
            contentType: widget.contentType,
            contentId: widget.contentId,
            contentTitle: widget.contentTitle,
            status: WatchStatus.watching,
            metadata: widget.metadata,
          );

      ref.invalidate(
        contentWatchHistoryProvider((
          ftpServerId: widget.ftpServerId,
          contentId: widget.contentId,
        )),
      );
    } catch (e) {
      // Error handled in finally block
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _updateStatus(
    WatchHistory? existingHistory,
    WatchStatus newStatus,
  ) async {
    setState(() {
      _isUpdating = true;
    });

    try {
      if (existingHistory != null) {
        await ref
            .read(watchHistoryNotifierProvider.notifier)
            .changeStatus(existingHistory.id, newStatus);
      } else {
        await ref
            .read(watchHistoryNotifierProvider.notifier)
            .updateStatus(
              ftpServerId: widget.ftpServerId,
              serverType: widget.serverType,
              contentType: widget.contentType,
              contentId: widget.contentId,
              contentTitle: widget.contentTitle,
              status: newStatus,
              metadata: widget.metadata,
            );
      }

      ref.invalidate(
        contentWatchHistoryProvider((
          ftpServerId: widget.ftpServerId,
          contentId: widget.contentId,
        )),
      );
    } catch (e) {
      // Error handled in finally block
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  IconData _getStatusIcon(WatchStatus status) {
    switch (status) {
      case WatchStatus.watching:
        return Icons.play_circle_outline;
      case WatchStatus.completed:
        return Icons.check_circle_outline;
      case WatchStatus.onHold:
        return Icons.pause_circle_outline;
      case WatchStatus.dropped:
        return Icons.cancel_outlined;
    }
  }

  Color _getStatusColor(WatchStatus status) {
    switch (status) {
      case WatchStatus.watching:
        return AppColors.primary;
      case WatchStatus.completed:
        return AppColors.success;
      case WatchStatus.onHold:
        return AppColors.warning;
      case WatchStatus.dropped:
        return AppColors.danger;
    }
  }
}
