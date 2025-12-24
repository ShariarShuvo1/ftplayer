import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';

import '../../../../app/theme/app_colors.dart';
import '../../../content_details/presentation/content_details_screen.dart';
import '../../data/home_models.dart';

class ContentCard extends ConsumerWidget {
  const ContentCard({required this.content, super.key});

  final ContentItem content;

  void _navigate(BuildContext context) {
    if (context.mounted) {
      context.push(ContentDetailsScreen.path, extra: content);
    }
  }

  Widget _buildImage(String imagePath) {
    final isLocalFile =
        imagePath.startsWith('/') ||
        imagePath.startsWith('file://') ||
        File(imagePath).existsSync();

    if (isLocalFile) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.surface,
            child: const Icon(Icons.movie, color: AppColors.textLow, size: 40),
          ),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: imagePath,
      fit: BoxFit.cover,
      placeholder: (context, url) => Shimmer(
        color: AppColors.primary.withValues(alpha: 0.3),
        child: Container(color: AppColors.surface),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.surface,
        child: const Icon(Icons.movie, color: AppColors.textLow, size: 40),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _navigate(context),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: 2 / 3,
                      child: content.posterUrl.isNotEmpty
                          ? _buildImage(content.posterUrl)
                          : Container(
                              color: AppColors.surface,
                              child: const Icon(
                                Icons.movie,
                                color: AppColors.textLow,
                                size: 40,
                              ),
                            ),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          content.serverName,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (content.quality != null && content.quality!.isNotEmpty)
                      Positioned(
                        bottom: 6,
                        left: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            content.quality!,
                            style: const TextStyle(
                              color: AppColors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                content.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textHigh,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
            if (content.year != null && content.year!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 12),
                child: Text(
                  content.year!,
                  style: const TextStyle(
                    color: AppColors.textLow,
                    fontSize: 10,
                    height: 1.2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
