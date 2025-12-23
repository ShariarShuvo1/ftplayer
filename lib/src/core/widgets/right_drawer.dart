import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../state/auth/auth_controller.dart';
import '../../state/ftp/working_ftp_servers_provider.dart';
import '../../state/ftp/all_ftp_servers_provider.dart';
import '../../state/ftp/ftp_availability_controller.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/ftp_servers/presentation/server_scan_screen.dart';
import '../../features/watch_history/presentation/watch_history_screen.dart';

class RightDrawer extends ConsumerWidget {
  const RightDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    final workingServersAsync = ref.watch(workingFtpServersProvider);
    final allServersAsync = ref.watch(allFtpServersProvider);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: const BoxDecoration(color: AppColors.surfaceAlt),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).pop();
                        context.push(ProfileScreen.path);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          session?.user.name ?? 'Guest',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox.shrink(),
                  IconButton(
                    tooltip: 'Logout',
                    icon: const Icon(
                      Icons.logout_outlined,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).logout();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 18),
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
                            onPressed: () {
                              Navigator.of(context).pop();
                              ref
                                  .read(
                                    ftpAvailabilityControllerProvider.notifier,
                                  )
                                  .reset();
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
                      ),
                      const SizedBox(height: 24),
                      _buildWatchHistoryItem(context),
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

  Widget _buildServerTile(BuildContext context, server, bool isWorking) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Opacity(
        opacity: isWorking ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isWorking
                  ? AppColors.success.withValues(alpha: 0.3)
                  : AppColors.surfaceAlt,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isWorking ? Icons.check_circle : Icons.cancel,
                color: isWorking ? AppColors.success : AppColors.textLow,
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
                        color: isWorking
                            ? AppColors.textHigh
                            : AppColors.textLow,
                      ),
                    ),
                    Text(
                      server.serverType.toUpperCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isWorking
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
    );
  }

  Widget _buildServersList(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<dynamic>> workingServersAsync,
    AsyncValue<List<dynamic>> allServersAsync,
  ) {
    return workingServersAsync.when(
      data: (workingServers) {
        return allServersAsync.when(
          data: (allServers) {
            if (workingServers.isEmpty && allServers.isEmpty) {
              return Text(
                'No servers configured',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMid),
              );
            }

            final workingIds = workingServers.map((s) => s.id).toSet();
            final workingServersList = allServers
                .where((s) => workingIds.contains(s.id))
                .toList();
            final nonWorkingServersList = allServers
                .where((s) => !workingIds.contains(s.id))
                .toList();

            final orderedServers = [
              ...workingServersList,
              ...nonWorkingServersList,
            ];

            final displayServers =
                orderedServers.isEmpty && workingServers.isNotEmpty
                ? workingServers
                : orderedServers;

            return Column(
              children: List.generate(displayServers.length, (index) {
                final server = displayServers[index];
                final isWorking = workingIds.contains(server.id);
                return _buildServerTile(context, server, isWorking);
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
                return _buildServerTile(context, server, true);
              }),
            );
          },
          error: (e, _) {
            if (workingServers.isEmpty) {
              return Text(
                'Error loading servers',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              );
            }
            return Column(
              children: List.generate(workingServers.length, (index) {
                final server = workingServers[index];
                return _buildServerTile(context, server, true);
              }),
            );
          },
        );
      },
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text(
        'Error loading servers',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
      ),
    );
  }

  Widget _buildWatchHistoryItem(BuildContext context) {
    final isOnWatchHistory =
        GoRouter.of(
          context,
        ).routerDelegate.currentConfiguration.last.matchedLocation ==
        WatchHistoryScreen.path;

    return GestureDetector(
      onTap: !isOnWatchHistory
          ? () {
              Navigator.of(context).pop();
              context.push(WatchHistoryScreen.path);
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
                isOnWatchHistory ? Icons.check_circle : Icons.arrow_forward_ios,
                color: isOnWatchHistory ? AppColors.success : AppColors.primary,
                size: isOnWatchHistory ? 16 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
