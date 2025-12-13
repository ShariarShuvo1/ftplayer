import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.leading,
    this.actions,
    this.bottom,
    this.padding,
    this.endDrawer,
  });

  final Widget body;
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final EdgeInsetsGeometry? padding;
  final Widget? endDrawer;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar:
          (title == null &&
              leading == null &&
              (actions == null || actions!.isEmpty) &&
              bottom == null)
          ? null
          : AppBar(
              title: title == null
                  ? null
                  : Text(title!, style: textTheme.titleLarge),
              leading: leading,
              actions: actions,
              bottom: bottom,
            ),
      endDrawer: endDrawer,
      body: SafeArea(
        child: Padding(
          padding:
              padding ??
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: body,
        ),
      ),
      backgroundColor: AppColors.black,
    );
  }
}
