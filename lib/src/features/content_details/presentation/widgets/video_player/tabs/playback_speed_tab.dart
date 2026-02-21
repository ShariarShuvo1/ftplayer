import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../../../app/theme/app_colors.dart';
import '../../../../../../core/utils/vibration_helper.dart';
import '../../../../../../state/settings/vibration_settings_provider.dart';

class PlaybackSpeedTab extends StatefulWidget {
  const PlaybackSpeedTab({
    required this.player,
    required this.currentSpeed,
    required this.onSpeedChanged,
    super.key,
  });

  final Player player;
  final double currentSpeed;
  final Function(double) onSpeedChanged;

  static const List<double> _speedOptions = [
    0.25,
    0.5,
    0.75,
    1.0,
    1.25,
    1.5,
    1.75,
    2.0,
    3.0,
    4.0,
  ];

  @override
  State<PlaybackSpeedTab> createState() => _PlaybackSpeedTabState();
}

class _PlaybackSpeedTabState extends State<PlaybackSpeedTab> {
  StreamSubscription? _rateSubscription;

  @override
  void initState() {
    super.initState();
    _rateSubscription = widget.player.stream.rate.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _rateSubscription?.cancel();
    super.dispose();
  }

  String _formatSpeed(double speed) {
    if (speed == 1.0) {
      return 'Normal';
    }
    return '${speed}x';
  }

  @override
  Widget build(BuildContext context) {
    final currentSpeed = widget.player.state.rate;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: PlaybackSpeedTab._speedOptions.length,
      itemBuilder: (context, index) {
        final speed = PlaybackSpeedTab._speedOptions[index];
        final isSelected = (currentSpeed - speed).abs() < 0.01;

        return _SpeedOption(
          speed: speed,
          label: _formatSpeed(speed),
          isSelected: isSelected,
          onTap: () {
            widget.onSpeedChanged(speed);
          },
        );
      },
    );
  }
}

class _SpeedOption extends ConsumerWidget {
  const _SpeedOption({
    required this.speed,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final double speed;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        final vibrationSettings = ref.read(vibrationSettingsProvider);
        if (vibrationSettings.enabled &&
            vibrationSettings.vibrateOnBottomSheet) {
          VibrationHelper.vibrate(vibrationSettings.strength);
        }
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.black,
          border: Border(
            left: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
            else
              const Icon(
                Icons.circle_outlined,
                color: Colors.white30,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (speed == 1.0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Default',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
