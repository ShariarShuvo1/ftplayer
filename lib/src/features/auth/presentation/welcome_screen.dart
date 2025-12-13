import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const path = '/welcome';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outline),
                ),
                child: const Icon(
                  Icons.play_circle_outline,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text('FTPlayer', style: textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: 22),
          Text('Stream your FTP videos', style: textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(
            'Sign in to sync your settings and securely access your account.',
            style: textTheme.bodyLarge,
          ),
          const Spacer(),
          PrimaryButton(
            label: 'Get started',
            icon: Icons.person_add_alt_1_outlined,
            onPressed: () => context.go(SignupScreen.path),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Login',
            icon: Icons.login,
            onPressed: () => context.go(LoginScreen.path),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
