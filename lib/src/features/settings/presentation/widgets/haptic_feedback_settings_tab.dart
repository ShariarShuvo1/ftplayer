import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/vibration_helper.dart';
import '../../../../state/settings/vibration_settings_provider.dart';

class HapticFeedbackSettingsTab extends ConsumerWidget {
  const HapticFeedbackSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibrationSettings = ref.watch(vibrationSettingsProvider);
    final notifier = ref.read(vibrationSettingsProvider.notifier);

    return ListView(
      padding: const EdgeInsets.only(left: 4, top: 16, right: 4, bottom: 16),
      children: [
        const Text(
          'Haptic Feedback',
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Customize vibration settings for user interactions',
          style: TextStyle(
            color: AppColors.textMid.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline, width: 1),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vibration',
                          style: TextStyle(
                            color: AppColors.textHigh,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enable haptic feedback for button interactions',
                          style: TextStyle(
                            color: AppColors.textMid.withValues(alpha: 0.8),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: vibrationSettings.enabled,
                    onChanged: (_) {
                      if (!vibrationSettings.enabled) {
                        VibrationHelper.vibrate(vibrationSettings.strength);
                      }
                      notifier.toggleEnabled();
                    },
                    activeThumbColor: AppColors.primary,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ],
              ),
              if (vibrationSettings.enabled) ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Text(
                      'Strength',
                      style: TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _getStrengthLabel(vibrationSettings.strength),
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
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 9,
                    ),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: 1.0,
                    divisions: 4,
                    value: vibrationSettings.strength,
                    onChanged: (v) {
                      VibrationHelper.vibrate(v);
                      notifier.updateStrength(v);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        AbsorbPointer(
          absorbing: !vibrationSettings.enabled,
          child: Opacity(
            opacity: vibrationSettings.enabled ? 1.0 : 0.5,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline, width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vibration Triggers',
                    style: TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tab Changes',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate when switching tabs',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnTabChange,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnTabChange) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnTabChange();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'App Bar',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on app bar buttons',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnAppbar,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnAppbar) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnAppbar();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Menu Navigation',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on menu interactions',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnMenuNavigation,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnMenuNavigation) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnMenuNavigation();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Download Screen',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on download interactions',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnDownloadScreen,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnDownloadScreen) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnDownloadScreen();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Watch History',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on fullscreen, settings, rotate icons, and download button feedback',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnWatchHistory,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnWatchHistory) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnWatchHistory();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        AbsorbPointer(
          absorbing: !vibrationSettings.enabled,
          child: Opacity(
            opacity: vibrationSettings.enabled ? 1.0 : 0.5,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outline, width: 1),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Content Details Screen',
                    style: TextStyle(
                      color: AppColors.textHigh,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Season Section',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on episode selection and actions',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnSeasonSection,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnSeasonSection) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnSeasonSection();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Download Button',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on download button interactions',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnDownloadButton,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnDownloadButton) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnDownloadButton();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Picture-in-Picture',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on PiP controls',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnPip,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnPip) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnPip();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gesture Controls',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on swipe gestures',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnGestures,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnGestures) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnGestures();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Video Controller',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on play/pause and episode navigation',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnVideoController,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnVideoController) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnVideoController();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Double Tap',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on double tap to seek',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnDoubleTap,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnDoubleTap) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnDoubleTap();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hold to Fast Forward',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate when holding for 2x speed',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnHoldFastForward,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnHoldFastForward) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnHoldFastForward();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bottom Sheet',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on media menu interactions',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnBottomSheet,
                        onChanged: (_) {
                          if (!vibrationSettings.vibrateOnBottomSheet) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnBottomSheet();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Other Controls',
                              style: TextStyle(
                                color: AppColors.textHigh,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Vibrate on fullscreen, settings, rotate icons',
                              style: TextStyle(
                                color: AppColors.textMid.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: vibrationSettings.vibrateOnContentDetailsOthers,
                        onChanged: (_) {
                          if (!vibrationSettings
                              .vibrateOnContentDetailsOthers) {
                            VibrationHelper.vibrate(vibrationSettings.strength);
                          }
                          notifier.toggleVibrateOnContentDetailsOthers();
                        },
                        activeThumbColor: AppColors.primary,
                        activeTrackColor: AppColors.primary.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getStrengthLabel(double strength) {
    if (strength <= 0.2) return 'Very Light';
    if (strength <= 0.4) return 'Light';
    if (strength <= 0.6) return 'Moderate';
    if (strength <= 0.8) return 'Strong';
    return 'Very Strong';
  }
}
