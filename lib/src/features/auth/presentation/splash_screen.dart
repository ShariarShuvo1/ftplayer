import 'package:flutter/material.dart';

import '../../../core/widgets/app_scaffold.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  static const path = '/';

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      body: Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
