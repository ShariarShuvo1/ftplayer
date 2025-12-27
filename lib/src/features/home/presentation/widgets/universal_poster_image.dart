import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'dart:ui';
import 'dart:io';

import '../../../../app/theme/app_colors.dart';

class UniversalPosterImage extends StatelessWidget {
  const UniversalPosterImage({
    required this.imageUrl,
    required this.placeholderIcon,
    this.isLocalFile = false,
    this.width,
    this.height,
    this.borderRadius = 8.0,
    super.key,
  });

  final String imageUrl;
  final IconData placeholderIcon;
  final bool isLocalFile;
  final double? width;
  final double? height;
  final double borderRadius;

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Icon(placeholderIcon, color: AppColors.textLow, size: 40),
      ),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (isLocalFile) {
      final file = File(imageUrl);
      if (file.existsSync()) {
        return _buildFileImage(file);
      }
      return _buildPlaceholder();
    }

    return _buildNetworkImage();
  }

  Widget _buildFileImage(File file) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
    );
  }

  Widget _buildNetworkImage() {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Shimmer(
        color: AppColors.primary.withValues(alpha: 0.3),
        child: Container(color: AppColors.surface),
      ),
      errorWidget: (context, url, error) => _buildPlaceholder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return _buildPlaceholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _BlurredBackground(imageUrl: imageUrl, isLocalFile: isLocalFile),
          Positioned.fill(child: _buildImage(context)),
        ],
      ),
    );
  }
}

class _BlurredBackground extends StatelessWidget {
  const _BlurredBackground({required this.imageUrl, required this.isLocalFile});

  final String imageUrl;
  final bool isLocalFile;

  Widget _buildBackgroundImage() {
    if (isLocalFile) {
      final file = File(imageUrl);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Container(color: AppColors.surface),
        );
      }
      return Container(color: AppColors.surface);
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: AppColors.surface),
      errorWidget: (context, url, error) => Container(color: AppColors.surface),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Transform.scale(scale: 1.2, child: _buildBackgroundImage()),
    );
  }
}
