import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/router.dart' show initializationProvider;
import '../../../core/storage/first_time_storage.dart';
import '../../../state/connectivity/connectivity_provider.dart';
import '../../ftp_servers/presentation/server_scan_screen.dart';

class FirstTimeWelcomeScreen extends ConsumerWidget {
  const FirstTimeWelcomeScreen({super.key});

  static const path = '/welcome';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(offlineModeProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset('assets/app_logo.png', width: 100, height: 100),
              const SizedBox(height: 32),
              Text(
                'Welcome to FTPlayer',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textHigh,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Stream and download content from FTP servers',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textMid),
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: isOffline
                    ? null
                    : () async {
                        final storage = ref.read(firstTimeStorageProvider);
                        await storage.markWelcomeShown();
                        ref.invalidate(initializationProvider);

                        if (context.mounted) {
                          context.go(ServerScanScreen.path);
                        }
                      },
                child: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
