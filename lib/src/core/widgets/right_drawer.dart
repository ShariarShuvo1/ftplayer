import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/router.dart';
import '../../core/utils/vibration_helper.dart';
import '../../state/ftp/working_ftp_servers_provider.dart';
import '../../state/ftp/all_ftp_servers_provider.dart';
import '../../state/ftp/ftp_availability_controller.dart';
import '../../state/ftp/enabled_servers_provider.dart';
import '../../state/connectivity/connectivity_provider.dart';
import '../../state/settings/vibration_settings_provider.dart';
import 'package:go_router/go_router.dart';
import '../../features/ftp_servers/presentation/server_scan_screen.dart';
import '../../features/watch_history/presentation/watch_history_screen.dart';
import '../../features/downloads/presentation/downloads_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

class RightDrawer extends ConsumerWidget {
  const RightDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workingServersAsync = ref.watch(workingFtpServersProvider);
    final allServersAsync = ref.watch(allFtpServersProvider);
    final enabledIdsAsync = ref.watch(enabledServerIdsProvider);
    final isOffline = ref.watch(offlineModeProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
                      if (!isOffline) ...[
                        Row(
                          children: [
                            const Icon(
                              Icons.storage,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'FTP Servers',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textHigh,
                                    ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Sync Availability',
                              icon: const Icon(
                                Icons.sync,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                final vibrationSettings = ref.read(
                                  vibrationSettingsProvider,
                                );
                                if (vibrationSettings.enabled &&
                                    vibrationSettings.vibrateOnMenuNavigation) {
                                  await VibrationHelper.vibrate(
                                    vibrationSettings.strength,
                                  );
                                }
                                if (!context.mounted) return;
                                Navigator.of(context).pop();
                                ref
                                    .read(
                                      ftpAvailabilityControllerProvider
                                          .notifier,
                                    )
                                    .reset();
                                if (!context.mounted) return;
                                context.push(ServerScanScreen.path);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildServersList(
                          context,
                          ref,
                          workingServersAsync,
                          allServersAsync,
                          enabledIdsAsync,
                          isOffline,
                        ),
                        const SizedBox(height: 24),
                      ],
                      _buildSettingsItem(context, ref, isOffline),
                      const SizedBox(height: 12),
                      _buildDownloadsItem(context, ref, isOffline),
                      const SizedBox(height: 12),
                      _buildWatchHistoryItem(context, ref, isOffline),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerTile(
    BuildContext context,
    server,
    bool isWorking,
    bool isEnabled,
    Future<void> Function() onToggle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: isWorking ? onToggle : null,
        child: Opacity(
          opacity: isWorking ? (isEnabled ? 1.0 : 0.5) : 0.4,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isWorking && isEnabled
                    ? AppColors.success.withValues(alpha: 0.3)
                    : (isWorking && !isEnabled
                          ? AppColors.textLow.withValues(alpha: 0.2)
                          : AppColors.surfaceAlt),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isWorking
                      ? (isEnabled
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked)
                      : Icons.cancel,
                  color: isWorking
                      ? (isEnabled ? AppColors.success : AppColors.textMid)
                      : AppColors.textLow,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isWorking && isEnabled
                              ? AppColors.textHigh
                              : AppColors.textLow,
                        ),
                      ),
                      Text(
                        server.serverType.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isWorking && isEnabled
                              ? AppColors.textMid
                              : AppColors.textLow,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServersList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<dynamic>> workingServersAsync,
    AsyncValue<List<dynamic>> allServersAsync,
    AsyncValue<List<String>> enabledIdsAsync,
    bool isOffline,
  ) {
    return workingServersAsync.when(
      data: (workingServers) {
        return allServersAsync.when(
          data: (allServers) {
            return enabledIdsAsync.when(
              data: (enabledIds) {
                if (workingServers.isEmpty && allServers.isEmpty) {
                  return Text(
                    'No servers configured',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppColors.textMid),
                  );
                }

                if (workingServers.isEmpty && allServers.isNotEmpty) {
                  return Column(
                    children: List.generate(allServers.length, (index) {
                      final server = allServers[index];
                      return _buildServerTile(
                        context,
                        server,
                        false,
                        false,
                        () async {},
                      );
                    }),
                  );
                }

                final workingIds = workingServers.map((s) => s.id).toSet();
                final workingServersList = allServers
                    .where((s) => workingIds.contains(s.id))
                    .toList();

                final displayServers =
                    workingServersList.isEmpty && workingServers.isNotEmpty
                    ? workingServers
                    : workingServersList;

                return Column(
                  children: List.generate(displayServers.length, (index) {
                    final server = displayServers[index];
                    final isWorking = workingIds.contains(server.id);
                    final isEnabled = enabledIds.contains(server.id);
                    final vibrationSettings = ref.watch(
                      vibrationSettingsProvider,
                    );

                    return _buildServerTile(
                      context,
                      server,
                      isWorking,
                      isEnabled,
                      () async {
                        if (vibrationSettings.enabled &&
                            vibrationSettings.vibrateOnMenuNavigation) {
                          await VibrationHelper.vibrate(
                            vibrationSettings.strength,
                          );
                        }
                        ref
                            .read(enabledServersControllerProvider.notifier)
                            .toggleServer(server.id);
                      },
                    );
                  }),
                );
              },
              loading: () {
                if (workingServers.isEmpty) {
                  return const CircularProgressIndicator();
                }
                return Column(
                  children: List.generate(workingServers.length, (index) {
                    final server = workingServers[index];
                    return _buildServerTile(
                      context,
                      server,
                      true,
                      true,
                      () async {},
                    );
                  }),
                );
              },
              error: (e, _) {
                if (workingServers.isEmpty) {
                  return const CircularProgressIndicator();
                }
                return Column(
                  children: List.generate(workingServers.length, (index) {
                    final server = workingServers[index];
                    return _buildServerTile(
                      context,
                      server,
                      true,
                      true,
                      () async {},
                    );
                  }),
                );
              },
            );
          },
          loading: () {
            if (workingServers.isEmpty) {
              return const CircularProgressIndicator();
            }
            return Column(
              children: List.generate(workingServers.length, (index) {
                final server = workingServers[index];
                return _buildServerTile(
                  context,
                  server,
                  true,
                  true,
                  () async {},
                );
              }),
            );
          },
          error: (e, _) {
            if (workingServers.isEmpty) {
              return Text(
                isOffline
                    ? 'Servers unavailable offline'
                    : 'Error loading servers',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isOffline ? AppColors.textLow : AppColors.danger,
                ),
              );
            }
            return Column(
              children: List.generate(workingServers.length, (index) {
                final server = workingServers[index];
                return _buildServerTile(
                  context,
                  server,
                  true,
                  true,
                  () async {},
                );
              }),
            );
          },
        );
      },
      loading: () => Column(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading servers...',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMid),
          ),
        ],
      ),
      error: (e, _) => Text(
        isOffline ? 'Servers unavailable offline' : 'Error loading servers',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: isOffline ? AppColors.textLow : AppColors.danger,
        ),
      ),
    );
  }

  Widget _buildSettingsItem(
    BuildContext context,
    WidgetRef ref,
    bool isOffline,
  ) {
    final isOnSettings =
        GoRouter.of(
          context,
        ).routerDelegate.currentConfiguration.last.matchedLocation ==
        SettingsScreen.path;

    return GestureDetector(
      onTap: !isOnSettings
          ? () {
              final vibrationSettings = ref.read(vibrationSettingsProvider);
              if (vibrationSettings.enabled &&
                  vibrationSettings.vibrateOnMenuNavigation) {
                VibrationHelper.vibrate(vibrationSettings.strength);
              }
              Navigator.of(context).pop();
              navigateToDrawerScreen(context, SettingsScreen.path);
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isOnSettings
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.settings, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Settings',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    isOnSettings ? 'Currently viewing' : 'App preferences',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isOnSettings
                          ? AppColors.success.withValues(alpha: 0.7)
                          : AppColors.textMid,
                    ),
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: isOnSettings ? 0.5 : 1.0,
              child: Icon(
                isOnSettings ? Icons.check_circle : Icons.arrow_forward_ios,
                color: AppColors.primary,
                size: isOnSettings ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadsItem(
    BuildContext context,
    WidgetRef ref,
    bool isOffline,
  ) {
    final isOnDownloads =
        GoRouter.of(
          context,
        ).routerDelegate.currentConfiguration.last.matchedLocation ==
        DownloadsScreen.path;

    return GestureDetector(
      onTap: !isOnDownloads
          ? () {
              final vibrationSettings = ref.read(vibrationSettingsProvider);
              if (vibrationSettings.enabled &&
                  vibrationSettings.vibrateOnMenuNavigation) {
                VibrationHelper.vibrate(vibrationSettings.strength);
              }
              Navigator.of(context).pop();
              navigateToDrawerScreen(context, DownloadsScreen.path);
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isOnDownloads
              ? AppColors.success.withValues(alpha: 0.2)
              : AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success, width: 1),
        ),
        child: Row(
          children: [
            Icon(
              Icons.download_for_offline_rounded,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Downloads',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                  Text(
                    isOnDownloads ? 'Currently viewing' : 'Offline content',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isOnDownloads
                          ? AppColors.success.withValues(alpha: 0.7)
                          : AppColors.textMid,
                    ),
                  ),
                ],
              ),
            ),
            Opacity(
              opacity: isOnDownloads ? 0.5 : 1.0,
              child: Icon(
                isOnDownloads ? Icons.check_circle : Icons.arrow_forward_ios,
                color: AppColors.success,
                size: isOnDownloads ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatchHistoryItem(
    BuildContext context,
    WidgetRef ref,
    bool isOffline,
  ) {
    final workingServersAsync = ref.watch(workingFtpServersProvider);
    final isOnWatchHistory =
        GoRouter.of(
          context,
        ).routerDelegate.currentConfiguration.last.matchedLocation ==
        WatchHistoryScreen.path;

    return workingServersAsync.when(
      data: (workingServers) {
        return GestureDetector(
          onTap: !isOnWatchHistory
              ? () {
                  final vibrationSettings = ref.read(vibrationSettingsProvider);
                  if (vibrationSettings.enabled &&
                      vibrationSettings.vibrateOnMenuNavigation) {
                    VibrationHelper.vibrate(vibrationSettings.strength);
                  }
                  Navigator.of(context).pop();
                  navigateToDrawerScreen(context, WatchHistoryScreen.path);
                }
              : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isOnWatchHistory
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary, width: 1),
            ),
            child: Opacity(
              opacity: 1.0,
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    color: isOnWatchHistory
                        ? AppColors.primary
                        : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Watch History',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isOnWatchHistory
                                    ? AppColors.primary
                                    : AppColors.primary,
                              ),
                        ),
                        Text(
                          isOnWatchHistory
                              ? 'Currently viewing'
                              : (isOffline
                                    ? 'Your local watch history'
                                    : 'Your watched content'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: isOnWatchHistory
                                    ? AppColors.success.withValues(alpha: 0.7)
                                    : AppColors.textMid,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: isOnWatchHistory ? 0.5 : 1.0,
                    child: Icon(
                      isOnWatchHistory
                          ? Icons.check_circle
                          : Icons.arrow_forward_ios,
                      color: isOnWatchHistory
                          ? AppColors.success
                          : AppColors.primary,
                      size: isOnWatchHistory ? 16 : 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => GestureDetector(
        onTap: !isOnWatchHistory
            ? () {
                final vibrationSettings = ref.read(vibrationSettingsProvider);
                if (vibrationSettings.enabled &&
                    vibrationSettings.vibrateOnMenuNavigation) {
                  VibrationHelper.vibrate(vibrationSettings.strength);
                }
                Navigator.of(context).pop();
                navigateToDrawerScreen(context, WatchHistoryScreen.path);
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isOnWatchHistory
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOnWatchHistory ? AppColors.primary : AppColors.primary,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history,
                color: isOnWatchHistory ? AppColors.primary : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watch History',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isOnWatchHistory
                            ? AppColors.primary
                            : AppColors.primary,
                      ),
                    ),
                    Text(
                      isOnWatchHistory
                          ? 'Currently viewing'
                          : 'Your watched content',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isOnWatchHistory
                            ? AppColors.success.withValues(alpha: 0.7)
                            : AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: isOnWatchHistory ? 0.5 : 1.0,
                child: Icon(
                  isOnWatchHistory
                      ? Icons.check_circle
                      : Icons.arrow_forward_ios,
                  color: isOnWatchHistory
                      ? AppColors.success
                      : AppColors.primary,
                  size: isOnWatchHistory ? 16 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (_, _) => GestureDetector(
        onTap: !isOnWatchHistory
            ? () {
                final vibrationSettings = ref.read(vibrationSettingsProvider);
                if (vibrationSettings.enabled &&
                    vibrationSettings.vibrateOnMenuNavigation) {
                  VibrationHelper.vibrate(vibrationSettings.strength);
                }
                Navigator.of(context).pop();
                navigateToDrawerScreen(context, WatchHistoryScreen.path);
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isOnWatchHistory
                ? AppColors.primary.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isOnWatchHistory ? AppColors.primary : AppColors.primary,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.history,
                color: isOnWatchHistory ? AppColors.primary : AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Watch History',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isOnWatchHistory
                            ? AppColors.primary
                            : AppColors.primary,
                      ),
                    ),
                    Text(
                      isOnWatchHistory
                          ? 'Currently viewing'
                          : 'Your watched content',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: isOnWatchHistory
                            ? AppColors.success.withValues(alpha: 0.7)
                            : AppColors.textMid,
                      ),
                    ),
                  ],
                ),
              ),
              Opacity(
                opacity: isOnWatchHistory ? 0.5 : 1.0,
                child: Icon(
                  isOnWatchHistory
                      ? Icons.check_circle
                      : Icons.arrow_forward_ios,
                  color: isOnWatchHistory
                      ? AppColors.success
                      : AppColors.primary,
                  size: isOnWatchHistory ? 16 : 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
