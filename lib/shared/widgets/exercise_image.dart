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

    // P9: constrain BOTH axes to the rendered pixel size so a 56dp list
    // thumbnail never decodes a 1200x800 JPEG at full resolution. Without
    // memCacheHeight, images passed only a height constraint (as the detail
    // sheet does) decoded at source resolution and stuffed the image cache
    // after a fast scroll through 150 exercises. One axis is enough —
    // CachedNetworkImage preserves aspect ratio from whichever dimension is
    // bounded — but supplying both prevents over-allocation when a caller
    // sets only one side.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final memCacheW = width != null ? (width! * dpr).round() : null;
    final memCacheH = height != null ? (height! * dpr).round() : null;

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: memCacheW,
        memCacheHeight: memCacheH,
        placeholder: (context, url) => _loading(theme),
        errorWidget: (context, url, error) => _fallback(theme),
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
