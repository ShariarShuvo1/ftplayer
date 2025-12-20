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
            const SizedBox(height: 18),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.storage,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'FTP Servers',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textHigh,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: workingServersAsync.when(
                        data: (workingServers) {
                          return allServersAsync.when(
                            data: (allServers) {
                              if (workingServers.isEmpty &&
                                  allServers.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No servers configured',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: AppColors.textMid),
                                  ),
                                );
                              }

                              final workingIds = workingServers
                                  .map((s) => s.id)
                                  .toSet();

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

                              if (orderedServers.isEmpty &&
                                  workingServers.isNotEmpty) {
                                return ListView.builder(
                                  itemCount: workingServers.length,
                                  itemBuilder: (context, index) {
                                    final server = workingServers[index];
                                    return _buildServerTile(
                                      context,
                                      server,
                                      true,
                                    );
                                  },
                                );
                              }

                              return ListView.builder(
                                itemCount: orderedServers.length,
                                itemBuilder: (context, index) {
                                  final server = orderedServers[index];
                                  final isWorking = workingIds.contains(
                                    server.id,
                                  );
                                  return _buildServerTile(
                                    context,
                                    server,
                                    isWorking,
                                  );
                                },
                              );
                            },
                            loading: () {
                              if (workingServers.isEmpty) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              return ListView.builder(
                                itemCount: workingServers.length,
                                itemBuilder: (context, index) {
                                  final server = workingServers[index];
                                  return _buildServerTile(
                                    context,
                                    server,
                                    true,
                                  );
                                },
                              );
                            },
                            error: (e, _) {
                              if (workingServers.isEmpty) {
                                return Center(
                                  child: Text(
                                    'Error loading servers',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: AppColors.danger),
                                  ),
                                );
                              }
                              return ListView.builder(
                                itemCount: workingServers.length,
                                itemBuilder: (context, index) {
                                  final server = workingServers[index];
                                  return _buildServerTile(
                                    context,
                                    server,
                                    true,
                                  );
                                },
                              );
                            },
                          );
                        },
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (e, _) => Center(
                          child: Text(
                            'Error loading servers',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.danger),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          ref
                              .read(ftpAvailabilityControllerProvider.notifier)
                              .reset();
                          context.push(ServerScanScreen.path);
                        },
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync Availability'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
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
}
