import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import '../../../../../../core/config/subtitle_settings.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../../../../core/utils/vibration_helper.dart';
import '../../../../../../core/widgets/custom_color_picker.dart';
import '../../../../../../state/settings/vibration_settings_provider.dart';

class SubtitlesTab extends StatefulWidget {
  const SubtitlesTab({
    required this.player,
    this.selectedIndex,
    required this.onSubtitleChanged,
    required this.settings,
    required this.onSettingsChanged,
    super.key,
  });

  final Player player;
  final int? selectedIndex;
  final Function(int) onSubtitleChanged;
  final SubtitleSettings settings;
  final ValueChanged<SubtitleSettings> onSettingsChanged;

  @override
  State<SubtitlesTab> createState() => _SubtitlesTabState();
}

class _SubtitlesTabState extends State<SubtitlesTab> {
  late SubtitleSettings _settings;
  StreamSubscription? _trackSubscription;

  @override
  void initState() {
    super.initState();
    _settings = widget.settings;
    _trackSubscription = widget.player.stream.track.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _updateSettings(SubtitleSettings newSettings) {
    setState(() {
      _settings = newSettings;
    });
    widget.onSettingsChanged(newSettings);
  }

  void _updateTextColor(int index, Color newColor) {
    final updatedPalette = List<Color>.from(_settings.textColorPalette);
    updatedPalette[index] = newColor;
    final newSettings = _settings.copyWith(textColorPalette: updatedPalette);
    _updateSettings(newSettings);
  }

  void _updateBackgroundColor(int index, Color newColor) {
    final updatedPalette = List<Color>.from(_settings.backgroundColorPalette);
    updatedPalette[index] = newColor;
    final newSettings = _settings.copyWith(
      backgroundColorPalette: updatedPalette,
    );
    _updateSettings(newSettings);
  }

  @override
  void didUpdateWidget(covariant SubtitlesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _settings = widget.settings;
    }
  }

  @override
  void dispose() {
    _trackSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subtitles = widget.player.state.tracks.subtitle;
    final currentSubtitleTrack = widget.player.state.track.subtitle;
    int? currentlyPlayingIndex;

    if (currentSubtitleTrack.id.isNotEmpty) {
      currentlyPlayingIndex = widget.player.state.tracks.subtitle.indexWhere(
        (track) => track.id == currentSubtitleTrack.id,
      );
      if (currentlyPlayingIndex == -1) {
        currentlyPlayingIndex = null;
      }
    }

    if (currentlyPlayingIndex == null &&
        currentSubtitleTrack.title?.isNotEmpty == true) {
      currentlyPlayingIndex = widget.player.state.tracks.subtitle.indexWhere(
        (track) =>
            track.title == currentSubtitleTrack.title &&
            track.language == currentSubtitleTrack.language,
      );
      if (currentlyPlayingIndex == -1) {
        currentlyPlayingIndex = null;
      }
    }

    if (subtitles.isEmpty) {
      return const Center(
        child: Text(
          'No subtitles available',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 12),
      children: [
        ...List.generate(subtitles.length, (index) {
          final subtitle = subtitles[index];
          final title = (subtitle.title?.isNotEmpty ?? false)
              ? subtitle.title!
              : (subtitle.language?.isNotEmpty ?? false)
              ? 'Subtitle - ${subtitle.language}'
              : 'Subtitle ${index + 1}';
          final isCurrentlyPlaying = index == currentlyPlayingIndex;
          return _SubtitleOption(
            title: title,
            isSelected: index == currentlyPlayingIndex,
            isCurrentlyPlaying: isCurrentlyPlaying,
            onTap: () {
              widget.onSubtitleChanged(index);
            },
          );
        }),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppColors.outline),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FontSizeRow(
                fontSize: _settings.fontSize,
                onChanged: (v) =>
                    _updateSettings(_settings.copyWith(fontSize: v)),
              ),
              const SizedBox(height: 12),
              _ColorRow(
                label: 'Text color',
                colors: _settings.textColorPalette,
                selected: _settings.textColor,
                onChanged: (c) =>
                    _updateSettings(_settings.copyWith(textColor: c)),
                onColorEdited: _updateTextColor,
              ),
              const SizedBox(height: 12),
              _ColorRow(
                label: 'Background',
                colors: _settings.backgroundColorPalette,
                selected: _settings.backgroundColor,
                onChanged: (c) =>
                    _updateSettings(_settings.copyWith(backgroundColor: c)),
                onColorEdited: _updateBackgroundColor,
              ),
              const SizedBox(height: 12),
              _OpacityRow(
                value: _settings.backgroundOpacity,
                onChanged: (v) =>
                    _updateSettings(_settings.copyWith(backgroundOpacity: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FontSizeRow extends ConsumerStatefulWidget {
  const _FontSizeRow({required this.fontSize, required this.onChanged});

  final double fontSize;
  final ValueChanged<double> onChanged;

  @override
  ConsumerState<_FontSizeRow> createState() => _FontSizeRowState();
}

class _FontSizeRowState extends ConsumerState<_FontSizeRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.fontSize.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(covariant _FontSizeRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fontSize != widget.fontSize) {
      _controller.text = widget.fontSize.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Font size',
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        _RoundIconButton(
          icon: Icons.remove,
          onTap: () {
            final vibrationSettings = ref.read(vibrationSettingsProvider);
            if (vibrationSettings.enabled &&
                vibrationSettings.vibrateOnBottomSheet) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            widget.onChanged((widget.fontSize - 1).clamp(8.0, 255.0));
          },
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 55,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              color: AppColors.textHigh,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.black,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.outline,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.outline,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.5,
                ),
              ),
            ),
            onSubmitted: (text) {
              final newValue = double.tryParse(text) ?? widget.fontSize;
              widget.onChanged(newValue.clamp(8.0, 255.0));
            },
          ),
        ),
        const SizedBox(width: 8),
        _RoundIconButton(
          icon: Icons.add,
          onTap: () {
            final vibrationSettings = ref.read(vibrationSettingsProvider);
            if (vibrationSettings.enabled &&
                vibrationSettings.vibrateOnBottomSheet) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            widget.onChanged((widget.fontSize + 1).clamp(8.0, 255.0));
          },
        ),
      ],
    );
  }
}

class _ColorRow extends ConsumerWidget {
  const _ColorRow({
    required this.label,
    required this.colors,
    required this.selected,
    required this.onChanged,
    required this.onColorEdited,
  });

  final String label;
  final List<Color> colors;
  final Color selected;
  final ValueChanged<Color> onChanged;
  final void Function(int index, Color color) onColorEdited;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textHigh,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...List.generate(colors.length, (index) {
                final c = colors[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ColorChip(
                    color: c,
                    selected: c.toARGB32() == selected.toARGB32(),
                    onTap: () => onChanged(c),
                    onLongPress: () async {
                      final newColor = await CustomColorPicker.show(
                        context: context,
                        initialColor: c,
                        ref: ref,
                      );
                      if (newColor != null) {
                        onColorEdited(index, newColor);
                        onChanged(newColor);
                      }
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpacityRow extends ConsumerWidget {
  const _OpacityRow({required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Background opacity',
              style: TextStyle(
                color: AppColors.textHigh,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: const TextStyle(
                color: AppColors.textMid,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.25),
            thumbColor: AppColors.primary,
            overlayColor: AppColors.primary.withValues(alpha: 0.15),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            min: 0.0,
            max: 1.0,
            value: value.clamp(0.0, 1.0),
            onChanged: (newValue) {
              final vibrationSettings = ref.read(vibrationSettingsProvider);
              if (vibrationSettings.enabled &&
                  vibrationSettings.vibrateOnBottomSheet) {
                VibrationHelper.vibrate(vibrationSettings.strength);
              }
              onChanged(newValue);
            },
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        child: Icon(icon, size: 16, color: AppColors.primary),
      ),
    );
  }
}

class _ColorChip extends ConsumerWidget {
  const _ColorChip({
    required this.color,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

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
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? AppColors.primary : Colors.white30,
            width: selected ? 2.0 : 1.0,
          ),
        ),
      ),
    );
  }
}

class _SubtitleOption extends ConsumerWidget {
  const _SubtitleOption({
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.isCurrentlyPlaying = false,
  });

  final String title;
  final bool isSelected;
  final bool isCurrentlyPlaying;
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
            if (isCurrentlyPlaying)
              const Icon(Icons.play_circle, color: AppColors.primary, size: 20)
            else if (isSelected)
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
                title,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : Colors.white,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
