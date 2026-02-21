import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../utils/vibration_helper.dart';
import '../../state/settings/vibration_settings_provider.dart';

class CustomColorPicker extends ConsumerStatefulWidget {
  const CustomColorPicker({
    required this.initialColor,
    required this.onColorSelected,
    super.key,
  });

  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  static Future<Color?> show({
    required BuildContext context,
    required Color initialColor,
    required WidgetRef ref,
  }) async {
    final vibrationSettings = ref.read(vibrationSettingsProvider);
    if (vibrationSettings.enabled) {
      await VibrationHelper.vibrate(vibrationSettings.strength);
    }

    if (!context.mounted) return null;

    return showDialog<Color>(
      context: context,
      builder: (context) => CustomColorPicker(
        initialColor: initialColor,
        onColorSelected: (color) => Navigator.of(context).pop(color),
      ),
    );
  }

  @override
  ConsumerState<CustomColorPicker> createState() => _CustomColorPickerState();
}

class _CustomColorPickerState extends ConsumerState<CustomColorPicker> {
  late Color _currentColor;
  late TextEditingController _hexController;

  int _getRed(Color c) => (c.r * 255.0).round() & 0xff;
  int _getGreen(Color c) => (c.g * 255.0).round() & 0xff;
  int _getBlue(Color c) => (c.b * 255.0).round() & 0xff;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
    _hexController = TextEditingController(text: _colorToHex(_currentColor));
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color color) {
    final r = _getRed(color).toRadixString(16).padLeft(2, '0');
    final g = _getGreen(color).toRadixString(16).padLeft(2, '0');
    final b = _getBlue(color).toRadixString(16).padLeft(2, '0');
    return '$r$g$b'.toUpperCase();
  }

  void _setControllerText(TextEditingController controller, String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _updateColor(Color color) {
    setState(() {
      _currentColor = color;
      _setControllerText(_hexController, _colorToHex(color));
    });
  }

  void _onHexChanged(String value) {
    if (value.length == 6) {
      final hex = int.tryParse(value, radix: 16);
      if (hex != null) {
        final color = Color(0xFF000000 | hex);
        setState(() {
          _currentColor = color;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final redValue = _getRed(_currentColor);
    final greenValue = _getGreen(_currentColor);
    final blueValue = _getBlue(_currentColor);

    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceAlt, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SwatchPreview(color: _currentColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          _HexRow(
                            controller: _hexController,
                            onChanged: _onHexChanged,
                          ),
                          const SizedBox(height: 10),
                          _RgbValueRow(
                            red: redValue,
                            green: greenValue,
                            blue: blueValue,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ChannelSliderRow(
                  label: 'R',
                  value: redValue,
                  activeColor: const Color(0xFFFF4D6D),
                  onChanged: (v) {
                    _updateColor(Color.fromARGB(255, v, greenValue, blueValue));
                  },
                ),
                const SizedBox(height: 8),
                _ChannelSliderRow(
                  label: 'G',
                  value: greenValue,
                  activeColor: const Color(0xFF35C784),
                  onChanged: (v) {
                    _updateColor(Color.fromARGB(255, redValue, v, blueValue));
                  },
                ),
                const SizedBox(height: 8),
                _ChannelSliderRow(
                  label: 'B',
                  value: blueValue,
                  activeColor: const Color(0xFF4D7DFF),
                  onChanged: (v) {
                    _updateColor(Color.fromARGB(255, redValue, greenValue, v));
                  },
                ),
                const SizedBox(height: 12),
                _ActionButtons(
                  onCancel: () {
                    final vibrationSettings = ref.read(
                      vibrationSettingsProvider,
                    );
                    if (vibrationSettings.enabled) {
                      VibrationHelper.vibrate(vibrationSettings.strength);
                    }
                    Navigator.of(context).pop();
                  },
                  onConfirm: () {
                    final vibrationSettings = ref.read(
                      vibrationSettingsProvider,
                    );
                    if (vibrationSettings.enabled) {
                      VibrationHelper.vibrate(vibrationSettings.strength);
                    }
                    widget.onColorSelected(_currentColor);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwatchPreview extends StatelessWidget {
  const _SwatchPreview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
    );
  }
}

class _HexRow extends StatelessWidget {
  const _HexRow({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.outline),
          ),
          child: const Text(
            '#',
            style: TextStyle(
              color: AppColors.textHigh,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              maxLength: 6,
              maxLines: 1,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f]')),
                UpperCaseTextFormatter(),
              ],
              style: const TextStyle(
                color: AppColors.textHigh,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: 'RRGGBB',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                filled: true,
                fillColor: AppColors.cardSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.2,
                  ),
                ),
              ),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _RgbValueRow extends StatelessWidget {
  const _RgbValueRow({
    required this.red,
    required this.green,
    required this.blue,
  });

  final int red;
  final int green;
  final int blue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ValueChip(
            label: 'R',
            value: red,
            color: const Color(0xFFFF4D6D),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ValueChip(
            label: 'G',
            value: green,
            color: const Color(0xFF35C784),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ValueChip(
            label: 'B',
            value: blue,
            color: const Color(0xFF4D7DFF),
          ),
        ),
      ],
    );
  }
}

class _ValueChip extends StatelessWidget {
  const _ValueChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value.toString(),
            style: const TextStyle(
              color: AppColors.textHigh,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableValueField extends StatefulWidget {
  const _EditableValueField({
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  @override
  State<_EditableValueField> createState() => _EditableValueFieldState();
}

class _EditableValueFieldState extends State<_EditableValueField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(_EditableValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      final newValue = int.tryParse(_controller.text)?.clamp(0, 255);
      if (newValue != null && newValue != widget.value) {
        widget.onChanged(newValue);
      } else {
        _controller.text = widget.value.toString();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 28,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: TextAlign.center,
        textAlignVertical: TextAlignVertical.center,
        keyboardType: TextInputType.number,
        maxLines: 1,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(3),
        ],
        style: const TextStyle(
          color: AppColors.textHigh,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 6,
            vertical: 6,
          ),
          filled: true,
          fillColor: AppColors.cardSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: widget.color, width: 1.2),
          ),
        ),
        onSubmitted: (text) {
          final newValue = int.tryParse(text)?.clamp(0, 255);
          if (newValue != null) {
            widget.onChanged(newValue);
          } else {
            _controller.text = widget.value.toString();
          }
        },
      ),
    );
  }
}

class _ChannelSliderRow extends ConsumerWidget {
  const _ChannelSliderRow({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final int value;
  final Color activeColor;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: activeColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: activeColor.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: activeColor,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: activeColor,
              inactiveTrackColor: AppColors.outline.withValues(alpha: 0.7),
              thumbColor: activeColor,
              overlayColor: activeColor.withValues(alpha: 0.10),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              min: 0,
              max: 255,
              value: value.toDouble(),
              onChanged: (v) {
                final vibrationSettings = ref.read(vibrationSettingsProvider);
                if (vibrationSettings.enabled) {
                  VibrationHelper.vibrate(vibrationSettings.strength);
                }
                onChanged(v.round());
              },
            ),
          ),
        ),
        const SizedBox(width: 10),
        _EditableValueField(
          value: value,
          color: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.onCancel, required this.onConfirm});

  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          height: 38,
          child: TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textMid,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 38,
          child: FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Apply',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
