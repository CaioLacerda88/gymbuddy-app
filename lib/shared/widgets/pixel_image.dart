import 'package:flutter/material.dart';

/// Thin wrapper around [Image.asset] that enforces nearest-neighbor scaling
/// for every pixel-art PNG in the app.
///
/// Using this widget instead of [Image.asset] directly is the rule the entire
/// pixel-art direction rests on: without `FilterQuality.none`, the GPU
/// bilinear-scales the PNG and our crisp 32/64px source art turns into a
/// blurred dark-gradient smear. That is a silent break — the app compiles,
/// the asset loads, it just stops looking like pixel art.
///
/// A required [semanticLabel] keeps the widget accessible. Decorative pixel
/// art that adds no information (e.g. a trailing chevron) should pass an
/// empty string explicitly so the omission is visible in code review.
///
/// Usage:
/// ```dart
/// PixelImage(
///   'assets/pixel/branding/repsaga_wordmark.png',
///   semanticLabel: 'RepSaga',
///   width: 256,
/// )
/// ```
class PixelImage extends StatelessWidget {
  const PixelImage(
    this.assetPath, {
    required this.semanticLabel,
    this.width,
    this.height,
    this.color,
    super.key,
  });

  /// Absolute asset path (e.g. `assets/pixel/nav/home_active.png`).
  final String assetPath;

  /// Screen-reader description. Pass an empty string for decorative-only art.
  final String semanticLabel;

  /// Optional width; preserves aspect ratio when only one axis is set.
  final double? width;

  /// Optional height; preserves aspect ratio when only one axis is set.
  final double? height;

  /// Optional tint applied via blend-mode srcIn — useful for rendering the
  /// same silhouette as a themed monochrome icon without shipping a second
  /// PNG.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      width: width,
      height: height,
      color: color,
      // Nearest-neighbor scaling is the whole point of shipping pixel art.
      // Flutter's default is FilterQuality.medium, which bilinear-blurs the
      // PNG and collapses distinct pixels into smoothed gradients.
      filterQuality: FilterQuality.none,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel.isEmpty ? null : semanticLabel,
      excludeFromSemantics: semanticLabel.isEmpty,
    );
  }
}
