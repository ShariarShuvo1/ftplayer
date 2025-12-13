import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/right_drawer.dart';
import '../../../app/theme/app_colors.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  static const path = '/home';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScaffold(
      title: 'Home',
      endDrawer: const RightDrawer(),
      actions: [
        Builder(
          builder: (context) {
            return IconButton(
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu),
              color: AppColors.primary,
            );
          },
        ),
      ],
      body: const Center(child: Text('Hello')),
    );
  }
}
