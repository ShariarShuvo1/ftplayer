import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/utils/vibration_helper.dart';
import '../../../../../state/settings/vibration_settings_provider.dart';
import '../../../data/content_details_models.dart';

class ContentDetailsSection extends ConsumerStatefulWidget {
  const ContentDetailsSection({
    required this.details,
    required this.onWatchStatusDropdown,
    this.onDownloadButton,
    this.skipInitialAnimation = false,
    this.isMinimizable = true,
    super.key,
  });

  final ContentDetails details;
  final Widget Function(ContentDetails) onWatchStatusDropdown;
  final Widget Function(ContentDetails)? onDownloadButton;
  final bool skipInitialAnimation;
  final bool isMinimizable;

  @override
  ConsumerState<ContentDetailsSection> createState() =>
      _ContentDetailsSectionState();
}

class _ContentDetailsSectionState extends ConsumerState<ContentDetailsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    if (widget.isMinimizable) {
      if (_isExpanded) {
        if (widget.skipInitialAnimation) {
          _animationController.forward(from: 1.0);
        } else {
          _animationController.forward();
        }
      }
    } else {
      _animationController.forward(from: 1.0);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() async {
    if (!widget.isMinimizable) return;

    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled &&
        vibrationSettings.vibrateOnContentDetailsOthers) {
      await VibrationHelper.vibrate(vibrationSettings.strength);
    }

    setState(() {
      _isExpanded = !_isExpanded;
    });
    if (_isExpanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: widget.isMinimizable ? _toggleExpanded : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: AppColors.outline.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(
                        ClipboardData(text: widget.details.title),
                      );
                    },
                    child: Text(
                      widget.details.title,
                      style: const TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (widget.isMinimizable)
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _animationController.value * 3.14159,
                        child: Icon(
                          Icons.expand_less,
                          color: AppColors.primary,
                          size: 28,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _animationController,
          axisAlignment: -1.0,
          child: Container(
            color: AppColors.black,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: widget.onWatchStatusDropdown(widget.details),
                      ),
                      if (widget.onDownloadButton != null &&
                          !widget.details.isSeries &&
                          widget.details.videoUrl != null &&
                          widget.details.videoUrl!.isNotEmpty) ...[
                        const SizedBox(width: 12),
                        widget.onDownloadButton!(widget.details),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildMetadata(),
                  if (widget.details.description != null &&
                      widget.details.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      widget.details.description!,
                      style: const TextStyle(
                        color: AppColors.textMid,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (widget.details.tags != null &&
                      widget.details.tags!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTags(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadata() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (widget.details.year != null) ...[
            Text(
              widget.details.year!,
              style: const TextStyle(color: AppColors.textMid, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Text(
              '•',
              style: TextStyle(color: AppColors.textMid, fontSize: 14),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.details.quality != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                widget.details.quality!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.details.watchTime != null) ...[
            const Text(
              '•',
              style: TextStyle(color: AppColors.textMid, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              widget.details.watchTime!,
              style: const TextStyle(color: AppColors.textMid, fontSize: 14),
            ),
          ],
          if (widget.details.rating != null) ...[
            const SizedBox(width: 8),
            const Text(
              '•',
              style: TextStyle(color: AppColors.textMid, fontSize: 14),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.star, color: AppColors.warning, size: 16),
            const SizedBox(width: 4),
            Text(
              widget.details.rating!.toStringAsFixed(1),
              style: const TextStyle(color: AppColors.textMid, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTags() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.details.tags!
          .split(',')
          .where((tag) => tag.trim().isNotEmpty)
          .map(
            (tag) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                tag.trim(),
                style: const TextStyle(color: AppColors.textLow, fontSize: 12),
              ),
            ),
          )
          .toList(),
    );
  }
}
