import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/utils/vibration_helper.dart';
import '../../../../state/ftp/working_ftp_servers_provider.dart';
import '../../../../state/settings/home_content_settings_provider.dart';
import '../../../../state/settings/vibration_settings_provider.dart';

class GeneralSettingsTab extends ConsumerStatefulWidget {
  const GeneralSettingsTab({super.key});

  @override
  ConsumerState<GeneralSettingsTab> createState() => _GeneralSettingsTabState();
}

class _GeneralSettingsTabState extends ConsumerState<GeneralSettingsTab> {
  String? _expandedSection;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(homeContentSettingsProvider);
    final notifier = ref.read(homeContentSettingsProvider.notifier);
    final workingServersAsync = ref.watch(workingFtpServersProvider);

    final serverStatus = workingServersAsync.when<Map<String, bool?>>(
      data: (servers) {
        final workingTypes = servers.map((server) => server.serverType).toSet();
        return {
          'circleftp': workingTypes.contains('circleftp'),
          'amaderftp': workingTypes.contains('amaderftp'),
          'dflix': workingTypes.contains('dflix'),
        };
      },
      loading: () => {'circleftp': null, 'amaderftp': null, 'dflix': null},
      error: (_, _) => {'circleftp': false, 'amaderftp': false, 'dflix': false},
    );

    return ListView(
      padding: const EdgeInsets.only(left: 4, top: 16, right: 4, bottom: 16),
      children: [
        const Text(
          'General Settings',
          style: TextStyle(
            color: AppColors.textHigh,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Home Screen Content',
          style: TextStyle(
            color: AppColors.textMid.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 24),
        _ContentSection(
          title: 'Featured',
          total:
              settings.featuredCircleFtp +
              settings.featuredAmaderFtp +
              settings.featuredDflix,
          isExpanded: _expandedSection == 'featured',
          onToggle: () => setState(() {
            _expandedSection = _expandedSection == 'featured'
                ? null
                : 'featured';
          }),
          circleFtpValue: settings.featuredCircleFtp,
          amaderFtpValue: settings.featuredAmaderFtp,
          dflixValue: settings.featuredDflix,
          circleFtpWorking: serverStatus['circleftp'],
          amaderFtpWorking: serverStatus['amaderftp'],
          dflixWorking: serverStatus['dflix'],
          onCircleFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(featuredCircleFtp: v)),
          onAmaderFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(featuredAmaderFtp: v)),
          onDflixChanged: (v) =>
              notifier.updateSettings(settings.copyWith(featuredDflix: v)),
        ),
        const SizedBox(height: 12),
        _ContentSection(
          title: 'Trending',
          total:
              settings.trendingCircleFtp +
              settings.trendingAmaderFtp +
              settings.trendingDflix,
          isExpanded: _expandedSection == 'trending',
          onToggle: () => setState(() {
            _expandedSection = _expandedSection == 'trending'
                ? null
                : 'trending';
          }),
          circleFtpValue: settings.trendingCircleFtp,
          amaderFtpValue: settings.trendingAmaderFtp,
          dflixValue: settings.trendingDflix,
          circleFtpWorking: serverStatus['circleftp'],
          amaderFtpWorking: serverStatus['amaderftp'],
          dflixWorking: serverStatus['dflix'],
          onCircleFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(trendingCircleFtp: v)),
          onAmaderFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(trendingAmaderFtp: v)),
          onDflixChanged: (v) =>
              notifier.updateSettings(settings.copyWith(trendingDflix: v)),
        ),
        const SizedBox(height: 12),
        _ContentSection(
          title: 'Latest Movies',
          total:
              settings.latestCircleFtp +
              settings.latestAmaderFtp +
              settings.latestDflix,
          isExpanded: _expandedSection == 'latest',
          onToggle: () => setState(() {
            _expandedSection = _expandedSection == 'latest' ? null : 'latest';
          }),
          circleFtpValue: settings.latestCircleFtp,
          amaderFtpValue: settings.latestAmaderFtp,
          dflixValue: settings.latestDflix,
          circleFtpWorking: serverStatus['circleftp'],
          amaderFtpWorking: serverStatus['amaderftp'],
          dflixWorking: serverStatus['dflix'],
          onCircleFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(latestCircleFtp: v)),
          onAmaderFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(latestAmaderFtp: v)),
          onDflixChanged: (v) =>
              notifier.updateSettings(settings.copyWith(latestDflix: v)),
        ),
        const SizedBox(height: 12),
        _ContentSection(
          title: 'TV Series',
          total:
              settings.tvSeriesCircleFtp +
              settings.tvSeriesAmaderFtp +
              settings.tvSeriesDflix,
          isExpanded: _expandedSection == 'tvseries',
          onToggle: () => setState(() {
            _expandedSection = _expandedSection == 'tvseries'
                ? null
                : 'tvseries';
          }),
          circleFtpValue: settings.tvSeriesCircleFtp,
          amaderFtpValue: settings.tvSeriesAmaderFtp,
          dflixValue: settings.tvSeriesDflix,
          circleFtpWorking: serverStatus['circleftp'],
          amaderFtpWorking: serverStatus['amaderftp'],
          dflixWorking: serverStatus['dflix'],
          onCircleFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(tvSeriesCircleFtp: v)),
          onAmaderFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(tvSeriesAmaderFtp: v)),
          onDflixChanged: (v) =>
              notifier.updateSettings(settings.copyWith(tvSeriesDflix: v)),
        ),
        const SizedBox(height: 12),
        Text(
          'Server Scan Ping Timeouts',
          style: TextStyle(
            color: AppColors.textMid.withValues(alpha: 0.8),
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        _PingTimeSection(
          circleFtpValue: settings.pingTimeCircleFtp,
          amaderFtpValue: settings.pingTimeAmaderFtp,
          dflixValue: settings.pingTimeDflix,
          circleFtpWorking: serverStatus['circleftp'],
          amaderFtpWorking: serverStatus['amaderftp'],
          dflixWorking: serverStatus['dflix'],
          onCircleFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(pingTimeCircleFtp: v)),
          onAmaderFtpChanged: (v) =>
              notifier.updateSettings(settings.copyWith(pingTimeAmaderFtp: v)),
          onDflixChanged: (v) =>
              notifier.updateSettings(settings.copyWith(pingTimeDflix: v)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ContentSection extends StatelessWidget {
  const _ContentSection({
    required this.title,
    required this.total,
    required this.isExpanded,
    required this.onToggle,
    required this.circleFtpValue,
    required this.amaderFtpValue,
    required this.dflixValue,
    required this.circleFtpWorking,
    required this.amaderFtpWorking,
    required this.dflixWorking,
    required this.onCircleFtpChanged,
    required this.onAmaderFtpChanged,
    required this.onDflixChanged,
  });

  final String title;
  final int total;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int circleFtpValue;
  final int amaderFtpValue;
  final int dflixValue;
  final bool? circleFtpWorking;
  final bool? amaderFtpWorking;
  final bool? dflixWorking;
  final ValueChanged<int> onCircleFtpChanged;
  final ValueChanged<int> onAmaderFtpChanged;
  final ValueChanged<int> onDflixChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textHigh,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary, width: 1),
                    ),
                    child: Text(
                      total.toString(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.outline),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _ServerValueRow(
                    serverName: 'CircleFTP',
                    value: circleFtpValue,
                    isWorking: circleFtpWorking,
                    onChanged: onCircleFtpChanged,
                  ),
                  const SizedBox(height: 12),
                  _ServerValueRow(
                    serverName: 'AmaderFTP',
                    value: amaderFtpValue,
                    isWorking: amaderFtpWorking,
                    onChanged: onAmaderFtpChanged,
                  ),
                  const SizedBox(height: 12),
                  _ServerValueRow(
                    serverName: 'Dflix',
                    value: dflixValue,
                    isWorking: dflixWorking,
                    onChanged: onDflixChanged,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ServerValueRow extends ConsumerWidget {
  const _ServerValueRow({
    required this.serverName,
    required this.value,
    required this.isWorking,
    required this.onChanged,
  });

  final String serverName;
  final int value;
  final bool? isWorking;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibrationSettings = ref.watch(vibrationSettingsProvider);
    final controller = TextEditingController(text: value.toString());
    final statusColor = isWorking == null
        ? AppColors.textLow.withValues(alpha: 0.6)
        : isWorking!
        ? AppColors.success
        : AppColors.danger;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                isWorking == null ? Icons.circle_outlined : Icons.circle,
                color: statusColor,
                size: 10,
              ),
              const SizedBox(width: 8),
              Text(
                serverName,
                style: const TextStyle(
                  color: AppColors.textMid,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            final newValue = (value - 1).clamp(0, 100);
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
              _NumericalRangeFormatter(min: 0, max: 100),
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
              onChanged(newValue.clamp(0, 100));
            },
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () {
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            final newValue = (value + 1).clamp(0, 100);
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

class _NumericalRangeFormatter extends TextInputFormatter {
  _NumericalRangeFormatter({required this.min, required this.max});

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

class _PingTimeSection extends StatelessWidget {
  const _PingTimeSection({
    required this.circleFtpValue,
    required this.amaderFtpValue,
    required this.dflixValue,
    required this.circleFtpWorking,
    required this.amaderFtpWorking,
    required this.dflixWorking,
    required this.onCircleFtpChanged,
    required this.onAmaderFtpChanged,
    required this.onDflixChanged,
  });

  final int circleFtpValue;
  final int amaderFtpValue;
  final int dflixValue;
  final bool? circleFtpWorking;
  final bool? amaderFtpWorking;
  final bool? dflixWorking;
  final ValueChanged<int> onCircleFtpChanged;
  final ValueChanged<int> onAmaderFtpChanged;
  final ValueChanged<int> onDflixChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timer_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  'Ping Time (seconds)',
                  style: const TextStyle(
                    color: AppColors.textHigh,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PingTimeRow(
              serverName: 'CircleFTP',
              value: circleFtpValue,
              isWorking: circleFtpWorking,
              onChanged: onCircleFtpChanged,
            ),
            const SizedBox(height: 12),
            _PingTimeRow(
              serverName: 'AmaderFTP',
              value: amaderFtpValue,
              isWorking: amaderFtpWorking,
              onChanged: onAmaderFtpChanged,
            ),
            const SizedBox(height: 12),
            _PingTimeRow(
              serverName: 'Dflix',
              value: dflixValue,
              isWorking: dflixWorking,
              onChanged: onDflixChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _PingTimeRow extends ConsumerWidget {
  const _PingTimeRow({
    required this.serverName,
    required this.value,
    required this.isWorking,
    required this.onChanged,
  });

  final String serverName;
  final int value;
  final bool? isWorking;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vibrationSettings = ref.watch(vibrationSettingsProvider);
    final controller = TextEditingController(text: value.toString());
    final statusColor = isWorking == null
        ? AppColors.textLow.withValues(alpha: 0.6)
        : isWorking!
        ? AppColors.success
        : AppColors.danger;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Icon(
                isWorking == null ? Icons.circle_outlined : Icons.circle,
                color: statusColor,
                size: 10,
              ),
              const SizedBox(width: 8),
              Text(
                serverName,
                style: const TextStyle(
                  color: AppColors.textMid,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () {
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            final newValue = (value - 1).clamp(1, 60);
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
              _PingTimeRangeFormatter(min: 1, max: 60),
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
              onChanged(newValue.clamp(1, 60));
            },
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () {
            if (vibrationSettings.enabled) {
              VibrationHelper.vibrate(vibrationSettings.strength);
            }
            final newValue = (value + 1).clamp(1, 60);
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

class _PingTimeRangeFormatter extends TextInputFormatter {
  _PingTimeRangeFormatter({required this.min, required this.max});

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
