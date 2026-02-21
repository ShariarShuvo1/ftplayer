import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';

class SkipIndicator extends StatelessWidget {
  const SkipIndicator({
    required this.label,
    required this.isForward,
    super.key,
  });

  final String label;
  final bool isForward;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        isForward ? '$label»' : '«$label',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 28,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
