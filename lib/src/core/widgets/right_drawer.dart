import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../state/auth/auth_controller.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/profile_screen.dart';

class RightDrawer extends ConsumerWidget {
  const RightDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
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
              child: Center(
                child: Text(
                  'Nothing to show',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
