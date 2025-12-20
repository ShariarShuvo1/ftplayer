import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../data/home_models.dart';
import 'content_card.dart';

class ContentSection extends StatelessWidget {
  const ContentSection({
    required this.title,
    required this.items,
    this.icon,
    super.key,
  });

  final String title;
  final List<ContentItem> items;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textHigh,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 258,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const PageScrollPhysics(),
            itemCount: items.length,
            itemExtent: 152,
            itemBuilder: (context, index) {
              return ContentCard(content: items[index]);
            },
          ),
        ),
      ],
    );
  }
}
