import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Fill options for [PixelPanel].
///
/// The pixel-art direction uses two canonical panel backgrounds, both locked
/// in the palette (§1.3 of the mockup brief). Anything else would leak
/// untracked hex into the UI.
enum PixelPanelFill {
  /// `AppColors.deepVoid` — deepest shadow, used for celebration overlays
  /// where the panel must recede against a hero element.
  deepVoid,

  /// `AppColors.duskPurple` — the mid-background, used for hero cards and
  /// empty states where the panel itself is the content.
  duskPurple,
}

/// 2-line bordered container in the RepSaga pixel-art style.
///
/// Structure (outside-in):
/// 1. 1-px `#000000` (true black) outer outline.
/// 2. 1-px `#8A3DC1` (`AppColors.arcanePurple`) inner sub-outline.
/// 3. Fill from [PixelPanelFill].
///
/// This mirrors the §4.11 panel-frame asset specified in the mockup brief
/// without shipping the asset — Flutter's `Container` decoration renders the
/// double border pixel-perfectly, so the PNG is redundant.
///
/// Used by celebration overlays (17a), empty states, and hero cards.
class PixelPanel extends StatelessWidget {
  const PixelPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.fill = PixelPanelFill.duskPurple,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final PixelPanelFill fill;

  @override
  Widget build(BuildContext context) {
    final fillColor = switch (fill) {
      PixelPanelFill.deepVoid => AppColors.deepVoid,
      PixelPanelFill.duskPurple => AppColors.duskPurple,
    };

    return DecoratedBox(
      // Outer: 1-px black outline.
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: DecoratedBox(
        // Inner: 1-px arcane-purple sub-outline + fill.
        decoration: BoxDecoration(
          color: fillColor,
          border: Border.all(color: AppColors.arcanePurple, width: 1),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
