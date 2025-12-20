import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/buttons.dart';
import '../../../state/ftp/ftp_availability_controller.dart';
import '../../../state/ftp/working_ftp_servers_provider.dart';

class ServerScanScreen extends ConsumerStatefulWidget {
  const ServerScanScreen({super.key});

  static const path = '/server-scan';

  @override
  ConsumerState<ServerScanScreen> createState() => _ServerScanScreenState();
}

class _ServerScanScreenState extends ConsumerState<ServerScanScreen> {
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(ftpAvailabilityControllerProvider.notifier)
          .startAvailabilityCheck();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ftpAvailabilityControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                'Checking Server Availability',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.isComplete
                    ? 'Scan complete'
                    : 'Testing connection to FTP servers...',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textMid),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildProgressSection(state),
              const SizedBox(height: 16),
              Expanded(child: _buildServerList(state)),
              const SizedBox(height: 16),
              if (state.isComplete) _buildButtonRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(FtpAvailabilityState state) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: state.isComplete ? 1.0 : state.progress,
                    strokeWidth: 6,
                    backgroundColor: AppColors.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      state.isComplete ? AppColors.success : AppColors.primary,
                    ),
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .rotate(duration: const Duration(seconds: 2), end: 1),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isComplete)
                  const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 36,
                      )
                      .animate()
                      .scale(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.elasticOut,
                      )
                      .fadeIn()
                else
                  Text(
                    '${(state.progress * 100).toInt()}%',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                if (!state.isComplete) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${state.checkedServers}/${state.totalServers}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textMid,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${state.availableServers} Working',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHigh,
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.cancel_outlined, color: AppColors.danger, size: 18),
              const SizedBox(width: 6),
              Text(
                '${state.unavailableServers} Not Working',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textHigh,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerList(FtpAvailabilityState state) {
    if (state.checkResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storage_outlined,
              size: 64,
              color: AppColors.textMid.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No FTP servers found',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textMid),
            ),
          ],
        ),
      );
    }

    final workingServers = state.checkResults
        .where((r) => r.status == ServerAvailabilityStatus.available)
        .toList();
    final notWorkingServers = state.checkResults
        .where((r) => r.status == ServerAvailabilityStatus.unavailable)
        .toList();
    final pendingOrChecking = state.checkResults
        .where(
          (r) =>
              r.status == ServerAvailabilityStatus.pending ||
              r.status == ServerAvailabilityStatus.checking,
        )
        .toList();

    final orderedResults = [
      ...workingServers,
      ...notWorkingServers,
      ...pendingOrChecking,
    ];

    return ListView.builder(
      itemCount: orderedResults.length,
      itemBuilder: (context, index) {
        final result = orderedResults[index];
        final isWorking = result.status == ServerAvailabilityStatus.available;
        final isNotWorking =
            result.status == ServerAvailabilityStatus.unavailable;
        return _buildServerTile(result, index, isWorking, isNotWorking)
            .animate()
            .fadeIn(
              delay: Duration(milliseconds: index * 50),
              duration: const Duration(milliseconds: 300),
            )
            .slideX(begin: 0.2, end: 0, curve: Curves.easeOut);
      },
    );
  }

  Widget _buildServerTile(
    ServerCheckResult result,
    int index,
    bool isWorking,
    bool isNotWorking,
  ) {
    IconData icon;
    Color iconColor;

    switch (result.status) {
      case ServerAvailabilityStatus.pending:
        icon = Icons.pending_outlined;
        iconColor = AppColors.textMid;
        break;
      case ServerAvailabilityStatus.checking:
        icon = Icons.sync;
        iconColor = AppColors.primary;
        break;
      case ServerAvailabilityStatus.available:
        icon = Icons.check_circle;
        iconColor = AppColors.success;
        break;
      case ServerAvailabilityStatus.unavailable:
        icon = Icons.cancel;
        iconColor = AppColors.danger;
        break;
    }

    return Opacity(
      opacity: isNotWorking ? 0.4 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isWorking
                ? AppColors.success.withValues(alpha: 0.3)
                : AppColors.surfaceAlt,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: result.status == ServerAvailabilityStatus.checking
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.server.name,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isNotWorking
                          ? AppColors.textLow
                          : AppColors.textHigh,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.server.serverType.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isNotWorking
                          ? AppColors.textLow
                          : AppColors.textMid,
                    ),
                  ),
                  if (result.pingUrl != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      result.pingUrl!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textLow,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (result.responseTime != null ||
                      result.statusCode != null ||
                      (result.errorMessage != null &&
                          result.status ==
                              ServerAvailabilityStatus.unavailable)) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (result.responseTime != null) ...[
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.textLow,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${result.responseTime!.inMilliseconds}ms',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color:
                                      result.responseTime!.inMilliseconds < 1000
                                      ? AppColors.success
                                      : result.responseTime!.inMilliseconds <
                                            3000
                                      ? AppColors.warning
                                      : AppColors.danger,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                        if ((result.responseTime != null ||
                                result.errorMessage != null) &&
                            result.statusCode != null)
                          const SizedBox(width: 8),
                        if (result.statusCode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  result.statusCode! >= 200 &&
                                      result.statusCode! < 300
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'HTTP ${result.statusCode}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color:
                                        result.statusCode! >= 200 &&
                                            result.statusCode! < 300
                                        ? AppColors.success
                                        : AppColors.danger,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        if ((result.responseTime != null ||
                                result.statusCode != null) &&
                            result.errorMessage != null &&
                            result.status ==
                                ServerAvailabilityStatus.unavailable)
                          const SizedBox(width: 8),
                        if (result.errorMessage != null &&
                            result.status ==
                                ServerAvailabilityStatus.unavailable) ...[
                          Icon(
                            Icons.error_outline,
                            size: 12,
                            color: AppColors.danger,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              result.errorMessage!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.danger,
                                    fontSize: 11,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonRow() {
    return Row(
      children: [
        Expanded(
          child:
              SecondaryButton(
                    onPressed: _isSaving
                        ? null
                        : () {
                            ref
                                .read(
                                  ftpAvailabilityControllerProvider.notifier,
                                )
                                .reset();
                            ref
                                .read(
                                  ftpAvailabilityControllerProvider.notifier,
                                )
                                .startAvailabilityCheck();
                          },
                    icon: Icons.refresh,
                    label: 'Rescan',
                  )
                  .animate()
                  .fadeIn(delay: const Duration(milliseconds: 200))
                  .slideY(begin: 0.3, end: 0),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _isSaving
              ? ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(
                      alpha: 0.7,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                )
              : PrimaryButton(
                      onPressed: () async {
                        if (_isSaving) return;
                        setState(() {
                          _isSaving = true;
                        });
                        try {
                          await ref
                              .read(ftpAvailabilityControllerProvider.notifier)
                              .saveWorkingServers();
                          if (mounted) {
                            ref.invalidate(workingFtpServersProvider);
                            context.go('/home');
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() {
                              _isSaving = false;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error saving servers: $e'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                          }
                        }
                      },
                      icon: Icons.arrow_forward,
                      label: 'Continue',
                    )
                    .animate()
                    .fadeIn(delay: const Duration(milliseconds: 300))
                    .slideY(begin: 0.3, end: 0),
        ),
      ],
    );
  }
}
