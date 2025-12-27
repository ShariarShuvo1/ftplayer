import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import 'universal_poster_image.dart';
import '../../../content_details/presentation/content_details_screen.dart';
import '../../data/home_models.dart';

class FeaturedCard extends ConsumerWidget {
  const FeaturedCard({required this.content, super.key});

  final ContentItem content;

  void _navigate(BuildContext context) {
    if (context.mounted) {
      context.push(ContentDetailsScreen.path, extra: content);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    bool isLocalFile(String url) {
      if (url.isEmpty) return false;
      final uri = Uri.tryParse(url);
      if (uri != null && uri.hasScheme) {
        return uri.scheme == 'file';
      }
      return !(url.startsWith('http://') || url.startsWith('https://'));
    }

    return GestureDetector(
      onTap: () => _navigate(context),
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        width: MediaQuery.of(context).size.width * 0.85,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 220,
            child: Stack(
              fit: StackFit.expand,
              children: [
                UniversalPosterImage(
                  imageUrl: content.posterUrl,
                  isLocalFile: isLocalFile(content.posterUrl),
                  placeholderIcon: Icons.movie,
                  borderRadius: 12,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      content.serverName,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 70),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.black.withValues(alpha: 0.2),
                          AppColors.black.withValues(alpha: 0.7),
                          AppColors.black.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          content.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (content.year != null &&
                                content.year!.isNotEmpty) ...[
                              Text(
                                content.year!,
                                style: const TextStyle(
                                  color: AppColors.textMid,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (content.quality != null &&
                                content.quality!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  content.quality!,
                                  style: const TextStyle(
                                    color: AppColors.black,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (content.rating != null) ...[
                              const SizedBox(width: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star,
                                    color: AppColors.warning,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    content.rating!.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: AppColors.textMid,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
