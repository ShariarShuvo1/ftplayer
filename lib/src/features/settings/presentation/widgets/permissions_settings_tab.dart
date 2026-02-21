import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/vibration_helper.dart';
import '../../../../state/settings/permissions_provider.dart';
import '../../../../state/settings/vibration_settings_provider.dart';

class PermissionsSettingsTab extends ConsumerWidget {
  const PermissionsSettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permissionState = ref.watch(permissionsProvider);

    final backgroundStatus =
        permissionState.permissions[PermissionType.backgroundDownloads] ??
        PermissionStatus.notRequired;

    if (permissionState.isLoading && permissionState.permissions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    final items = <Widget>[
      const Text(
        'App Permissions',
        style: TextStyle(
          color: AppColors.textHigh,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Manage permissions required for app features',
        style: TextStyle(
          color: AppColors.textMid.withValues(alpha: 0.8),
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 24),
      _BatteryTip(
        onOpenSettings: () {
          ref.read(permissionsProvider.notifier).openAppSettings();
        },
      ),
      const SizedBox(height: 16),
      _PermissionItem(
        icon: Icons.notifications_outlined,
        title: 'Notifications',
        description: 'Show download progress and completion alerts',
        permissionType: PermissionType.notification,
        status:
            permissionState.permissions[PermissionType.notification] ??
            PermissionStatus.denied,
        onRequest: () => ref
            .read(permissionsProvider.notifier)
            .requestNotificationPermission(),
        onOpenSettings: () =>
            ref.read(permissionsProvider.notifier).openAppSettings(),
      ),
      const SizedBox(height: 12),
      _PermissionItem(
        icon: Icons.storage_outlined,
        title: 'Storage',
        description: 'Save downloaded videos and posters to device',
        permissionType: PermissionType.storage,
        status:
            permissionState.permissions[PermissionType.storage] ??
            PermissionStatus.denied,
        onRequest: () =>
            ref.read(permissionsProvider.notifier).requestStoragePermission(),
        onOpenSettings: () =>
            ref.read(permissionsProvider.notifier).openAppSettings(),
      ),
    ];

    if (backgroundStatus != PermissionStatus.notRequired) {
      items.addAll([
        const SizedBox(height: 12),
        _PermissionItem(
          icon: Icons.cloud_download_outlined,
          title: 'Background downloads',
          description:
              'Allow downloads to keep running while the app is minimized',
          permissionType: PermissionType.backgroundDownloads,
          status: backgroundStatus,
          onRequest: () {},
          onOpenSettings: () =>
              ref.read(permissionsProvider.notifier).openAppSettings(),
        ),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.only(left: 4, top: 16, right: 4, bottom: 16),
      children: items,
    );
  }
}

class _BatteryTip extends ConsumerWidget {
  const _BatteryTip({required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.battery_saver_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Battery preference',
                  style: TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Open system settings and set FTPlayer battery usage to Unrestricted for more reliable background downloads.',
                  style: TextStyle(
                    color: AppColors.textMid.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    final vibrationSettings = ref.read(
                      vibrationSettingsProvider,
                    );
                    if (vibrationSettings.enabled) {
                      VibrationHelper.vibrate(vibrationSettings.strength);
                    }
                    onOpenSettings();
                  },
                  icon: const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Open battery settings'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionItem extends ConsumerWidget {
  const _PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.permissionType,
    required this.status,
    required this.onRequest,
    required this.onOpenSettings,
  });

  final IconData icon;
  final String title;
  final String description;
  final PermissionType permissionType;
  final PermissionStatus status;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: status == PermissionStatus.granted
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.outline,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: status == PermissionStatus.granted
                  ? AppColors.primary.withValues(alpha: 0.15)
                  : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: status == PermissionStatus.granted
                  ? AppColors.primary
                  : AppColors.textMid,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: AppColors.textMid.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                _buildStatusWidget(ref),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusWidget(WidgetRef ref) {
    if (status == PermissionStatus.notRequired) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.textMid.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'Not Required',
          style: TextStyle(
            color: AppColors.textMid.withValues(alpha: 0.9),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (status == PermissionStatus.granted) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: AppColors.primary, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Allowed',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: () {
            final vibrationSettings = ref.read(vibrationSettingsProvider);
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            onRequest();
          },
          icon: const Icon(Icons.lock_open, size: 16),
          label: const Text('Allow'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () {
            final vibrationSettings = ref.read(vibrationSettingsProvider);
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            onOpenSettings();
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textMid,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: const Text('Settings'),
        ),
      ],
    );
  }
}
