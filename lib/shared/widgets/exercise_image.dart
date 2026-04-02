import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Displays a cached network image with loading/error fallback.
/// Collapses to an empty SizedBox when [imageUrl] is null or empty.
class ExerciseImage extends StatelessWidget {
  const ExerciseImage({
    super.key,
    required this.imageUrl,
    required this.fallbackIcon,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.borderRadius = BorderRadius.zero,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _fallback(theme);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: width != null
            ? (width! * MediaQuery.devicePixelRatioOf(context)).round()
            : null,
        placeholder: (context, url) => _loading(theme),
        errorWidget: (context, url, error) => const SizedBox.shrink(),
        fadeInDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Widget _loading(ThemeData theme) {
    return Stack(
      children: [
        Container(
          width: width,
          height: height,
          color: theme.colorScheme.surface,
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(
            minHeight: 2,
            color: theme.colorScheme.primary,
            backgroundColor: Colors.transparent,
          ),
        ),
      ],
    );
  }

  Widget _fallback(ThemeData theme) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: borderRadius,
      ),
      child: Icon(
        fallbackIcon,
        size: (height ?? 48) * 0.4,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}
