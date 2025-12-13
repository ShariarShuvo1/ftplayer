import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppSnackbars {
  const AppSnackbars._();

  static void showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  softWrap: true,
                  maxLines: 5,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: AppColors.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  softWrap: true,
                  maxLines: 5,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        ),
      );
  }
}
