import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/vibration_helper.dart';
import '../../../../core/widgets/custom_color_picker.dart';
import '../../../../state/settings/subtitle_settings_provider.dart';
import '../../../../state/settings/vibration_settings_provider.dart';

class SubtitleSettingsTab extends ConsumerStatefulWidget {
  const SubtitleSettingsTab({super.key});

  @override
  ConsumerState<SubtitleSettingsTab> createState() =>
      _SubtitleSettingsTabState();
}

class _SubtitleSettingsTabState extends ConsumerState<SubtitleSettingsTab> {
  void _updateTextColor(int index, Color newColor) {
    final settings = ref.read(subtitleSettingsProvider);
    final updatedPalette = List<Color>.from(settings.textColorPalette);
    updatedPalette[index] = newColor;
    ref
        .read(subtitleSettingsProvider.notifier)
        .updateColorPalettes(textColorPalette: updatedPalette);
  }

  void _updateBackgroundColor(int index, Color newColor) {
    final settings = ref.read(subtitleSettingsProvider);
    final updatedPalette = List<Color>.from(settings.backgroundColorPalette);
    updatedPalette[index] = newColor;
    ref
        .read(subtitleSettingsProvider.notifier)
        .updateColorPalettes(backgroundColorPalette: updatedPalette);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(subtitleSettingsProvider);
    final notifier = ref.read(subtitleSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(left: 4, top: 16, right: 4, bottom: 16),
      children: [
        const Text(
          'Subtitle Appearance',
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        _FontSizeRow(
          fontSize: settings.fontSize,
          onChanged: (v) => notifier.updateFontSize(v),
        ),
        const SizedBox(height: 20),
        _ColorRow(
          label: 'Text color',
          colors: settings.textColorPalette,
          selected: settings.textColor,
          onChanged: (c) => notifier.updateTextColor(c),
          onColorEdited: _updateTextColor,
        ),
        const SizedBox(height: 20),
        _ColorRow(
          label: 'Background color',
          colors: settings.backgroundColorPalette,
          selected: settings.backgroundColor,
          onChanged: (c) => notifier.updateBackgroundColor(c),
          onColorEdited: _updateBackgroundColor,
        ),
        const SizedBox(height: 20),
        _OpacityRow(
          value: settings.backgroundOpacity,
          onChanged: (v) => notifier.updateBackgroundOpacity(v),
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
    final vibrationSettings = ref.watch(vibrationSettingsProvider);

    return Row(
      children: [
        const Text(
          'Font size',
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        _RoundIconButton(
          icon: Icons.remove,
          onTap: () {
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            widget.onChanged((widget.fontSize - 1).clamp(12.0, 64.0));
          },
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              final newValue = double.tryParse(text) ?? widget.fontSize;
              widget.onChanged(newValue.clamp(12.0, 64.0));
            },
          ),
        ),
        const SizedBox(width: 8),
        _RoundIconButton(
          icon: Icons.add,
          onTap: () {
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            widget.onChanged((widget.fontSize + 1).clamp(12.0, 64.0));
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
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...List.generate(colors.length, (index) {
                final c = colors[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
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
    final vibrationSettings = ref.watch(vibrationSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Background opacity',
              style: TextStyle(
                color: AppColors.textHigh,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
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
            min: 0.0,
            max: 1.0,
            value: value.clamp(0.0, 1.0),
            onChanged: (v) {
              if (vibrationSettings.enabled) {
                VibrationHelper.vibrate(vibrationSettings.strength);
              }
              onChanged(v);
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
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.15),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary, width: 1.2),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
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
        if (vibrationSettings.enabled) {
          VibrationHelper.vibrate(vibrationSettings.strength);
        }
        onTap();
      },
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: selected ? AppColors.primary : Colors.white30,
            width: selected ? 2.5 : 1.0,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: AppColors.primary, size: 18)
            : null,
      ),
    );
  }
}
