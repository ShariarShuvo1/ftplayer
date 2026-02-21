import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/vibration_helper.dart';
import '../../../../state/settings/video_playback_settings_provider.dart';
import '../../../../state/settings/vibration_settings_provider.dart';

class VideoControllerSettingsTab extends ConsumerWidget {
  const VideoControllerSettingsTab({super.key});

  static const List<double> _speedPresets = [
    0.25,
    0.5,
    0.75,
    1.25,
    1.5,
    1.75,
    2.0,
    3.0,
    4.0,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(videoPlaybackSettingsProvider);
    final notifier = ref.read(videoPlaybackSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(left: 4, top: 16, right: 4, bottom: 16),
      children: [
        const Text(
          'Video Controls',
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Hold to Speed',
          style: TextStyle(
            color: AppColors.textMid.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _speedPresets.map((speed) {
              final isSelected =
                  (settings.holdToSpeedRate - speed).abs() < 0.01;
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _SpeedChip(
                  speed: speed,
                  isSelected: isSelected,
                  onTap: () => notifier.updateHoldToSpeedRate(speed),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Double Tap Skip',
          style: TextStyle(
            color: AppColors.textMid.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        _SkipSecondsRow(
          label: 'Left (Rewind)',
          value: settings.leftDoubleTapSkipSeconds,
          onChanged: notifier.updateLeftDoubleTapSkipSeconds,
        ),
        const SizedBox(height: 12),
        _SkipSecondsRow(
          label: 'Right (Forward)',
          value: settings.rightDoubleTapSkipSeconds,
          onChanged: notifier.updateRightDoubleTapSkipSeconds,
        ),
        const SizedBox(height: 24),
        _ThresholdRow(
          value: settings.autoCompleteThreshold,
          presets: const [],
          onChanged: notifier.updateAutoCompleteThreshold,
        ),
      ],
    );
  }
}

class _SpeedChip extends ConsumerWidget {
  const _SpeedChip({
    required this.speed,
    required this.isSelected,
    required this.onTap,
  });

  final double speed;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibrationSettings = ref.watch(vibrationSettingsProvider);

    return InkWell(
      onTap: () {
        if (vibrationSettings.enabled) {
          VibrationHelper.vibrate(vibrationSettings.strength);
        }
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.15)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.outline,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(
                  Icons.check_circle,
                  color: AppColors.primary,
                  size: 16,
                ),
              ),
            Text(
              '${speed}x',
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textHigh,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThresholdRow extends ConsumerWidget {
  const _ThresholdRow({
    required this.value,
    required this.presets,
    required this.onChanged,
  });

  final int value;
  final List<int> presets;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibrationSettings = ref.watch(vibrationSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Completion Threshold',
              style: TextStyle(
                color: AppColors.textHigh,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '$value%',
              style: const TextStyle(
                color: AppColors.textMid,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          ),
          child: Slider(
            min: 50.0,
            max: 100.0,
            divisions: 50,
            value: value.toDouble().clamp(50.0, 100.0),
            onChanged: (v) {
              if (vibrationSettings.enabled) {
                VibrationHelper.vibrate(vibrationSettings.strength);
              }
              onChanged(v.round());
            },
          ),
        ),
      ],
    );
  }
}

class _ThresholdRangeFormatter extends TextInputFormatter {
  _ThresholdRangeFormatter({required this.min, required this.max});

  final int min;
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final intValue = int.tryParse(newValue.text);
    if (intValue == null) {
      return oldValue;
    }

    if (intValue < min || intValue > max) {
      return oldValue;
    }

    return newValue;
  }
}

class _SkipSecondsRow extends ConsumerWidget {
  const _SkipSecondsRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibrationSettings = ref.watch(vibrationSettingsProvider);
    final controller = TextEditingController(text: value.toString());

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textMid,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            final newValue = (value - 1).clamp(1, 99);
            onChanged(newValue);
          },
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.primary,
          iconSize: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              _ThresholdRangeFormatter(min: 1, max: 99),
            ],
            style: const TextStyle(
              color: AppColors.textHigh,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.black,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.outline,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.outline,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: (text) {
              final newValue = int.tryParse(text) ?? value;
              onChanged(newValue.clamp(1, 99));
            },
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () {
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            final newValue = (value + 1).clamp(1, 99);
            onChanged(newValue);
          },
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.primary,
          iconSize: 24,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }
}
