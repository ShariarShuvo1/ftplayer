import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../app/theme/app_colors.dart';
import '../../../state/auth/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  static const path = '/profile';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.valueOrNull?.user;
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      title: 'Profile',
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        color: AppColors.primary,
        onPressed: () => Navigator.of(context).pop(),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: AppColors.primary,
                child: Text(
                  (user?.name ?? '?').isNotEmpty
                      ? user!.name.substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                user?.name ?? '',
                style: textTheme.titleLarge?.copyWith(color: AppColors.primary),
              ),
            ),
            const SizedBox(height: 6),
            const SizedBox(height: 20),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Account', style: textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Email'),
                      subtitle: Text(user?.email ?? ''),
                    ),
                    const SizedBox(height: 4),
                    // User ID removed per design — only show email under Account
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
