import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Inline-SVG icon set for RepSaga's Arcane Ascent direction (§17.0c).
///
/// Each icon is a raw SVG string authored against a `0 0 48 48` viewBox,
/// monoline with `stroke="currentColor"` and `fill="none"` so a single
/// accessor can recolor + resize every icon. Filled variants use
/// `fill="currentColor"` instead.
///
/// All icons are rendered via [render] which wraps `SvgPicture.string` with
/// a `ColorFilter.mode(..., srcIn)` so the entire glyph picks up the passed
/// [Color]. Size is applied to both width and height for a square bounding
/// box — caller is responsible for wrapping in a SizedBox/Semantics as the
/// enclosing layout needs.
///
/// **Lift icon rule.** [lift] is a side-view barbell with asymmetric
/// rectangle plates (inner taller, outer shorter). Never a circle-on-stick
/// (that's a dumbbell) and never a generic gym emoji. This is the single
/// most-referenced icon in the codebase — it reads as "this is a lift app"
/// at 24 dp on the nav bar.
class AppIcons {
  const AppIcons._();

  // ---------------------------------------------------------------------
  // Primary nav
  // ---------------------------------------------------------------------

  /// Sanctum-arch home. Monoline stroke.
  static const String home =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M24 6 L40 22 V40 H8 V22 Z"/>'
      '<path d="M18 40 V28 C18 25 21 23 24 23 C27 25 30 25 30 28 V40"/>'
      '</svg>';

  /// Side-view barbell — bar + asymmetric rectangle plates (inner taller,
  /// outer shorter) on both sides. This is the app's signature icon.
  static const String lift =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" xmlns="http://www.w3.org/2000/svg">'
      // Barbell shaft.
      '<line x1="4" y1="24" x2="44" y2="24" stroke-width="2.8"/>'
      // Left inner plate (taller).
      '<rect x="8" y="14" width="6" height="20" rx="1"/>'
      // Left outer plate (shorter).
      '<rect x="2" y="17" width="5" height="14" rx="1"/>'
      // Right inner plate (taller).
      '<rect x="34" y="14" width="6" height="20" rx="1"/>'
      // Right outer plate (shorter).
      '<rect x="41" y="17" width="5" height="14" rx="1"/>'
      '</svg>';

  /// Scroll / plan icon. Monoline stroke.
  static const String plan =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 10 H38 V38 H12 Z"/>'
      '<path d="M8 10 C8 7 10 5 12 5 C14 5 16 7 16 10"/>'
      '<path d="M32 10 C32 7 34 5 36 5 C38 5 40 7 40 10"/>'
      '<path d="M18 18 H32 M18 24 H32 M18 30 H26" stroke-width="1.8"/>'
      '</svg>';

  /// Laurel / stats icon. Monoline stroke.
  static const String stats =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 40 C8 32 8 20 14 12"/>'
      '<path d="M36 40 C40 32 40 20 34 12"/>'
      '<path d="M24 40 V20" stroke-width="2.8"/>'
      '<path d="M20 34 L16 30 M28 34 L32 30 M18 28 L14 24 M30 28 L34 24 M16 22 L12 18 M32 22 L36 18" stroke-width="1.8"/>'
      '</svg>';

  /// Hooded-silhouette hero. Filled glyph (uses `fill="currentColor"`).
  static const String hero =
      '<svg viewBox="0 0 48 48" fill="currentColor" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M24 8 C16 8 12 14 12 22 V30 C14 30 16 32 16 36 H32 C32 32 34 30 36 30 V22 C36 14 32 8 24 8 Z"/>'
      '</svg>';

  // ---------------------------------------------------------------------
  // Reward / state
  // ---------------------------------------------------------------------

  /// XP bolt. Filled diamond-bolt silhouette.
  static const String xp =
      '<svg viewBox="0 0 48 48" fill="currentColor" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M26 4 L14 26 H22 L20 44 L34 22 H26 L28 4 Z"/>'
      '</svg>';

  /// Level-up star (5-point). Filled.
  static const String levelUp =
      '<svg viewBox="0 0 48 48" fill="currentColor" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M24 6 L28 18 L40 20 L31 28 L34 40 L24 34 L14 40 L17 28 L8 20 L20 18 Z"/>'
      '</svg>';

  /// Streak flame. Filled.
  static const String streak =
      '<svg viewBox="0 0 48 48" fill="currentColor" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M24 6 C20 14 16 18 16 26 C16 34 19 40 24 40 C29 40 32 34 32 26 C32 22 30 20 28 18 C27 22 26 24 24 24 C22 24 22 20 24 6 Z"/>'
      '</svg>';

  // ---------------------------------------------------------------------
  // Verbs
  // ---------------------------------------------------------------------

  /// Checkmark — confirmation, done-state.
  static const String check =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="3.2" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M10 24 L20 34 L38 14"/>'
      '</svg>';

  /// Plus — add / create.
  static const String add =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="3" '
      'stroke-linecap="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M24 10 V38 M10 24 H38"/>'
      '</svg>';

  /// Pencil — edit.
  static const String edit =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M10 38 L10 32 L30 12 L36 18 L16 38 Z"/>'
      '<path d="M28 14 L34 20"/>'
      '</svg>';

  /// Trash bin — delete.
  static const String delete =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M10 14 H38"/>'
      '<path d="M20 10 H28 V14"/>'
      '<path d="M14 14 L16 40 H32 L34 14"/>'
      '<path d="M20 20 V34 M28 20 V34" stroke-width="1.8"/>'
      '</svg>';

  /// Three horizontal bars — filter.
  static const String filter =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.8" '
      'stroke-linecap="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M8 14 H40"/>'
      '<path d="M14 24 H34"/>'
      '<path d="M20 34 H28"/>'
      '</svg>';

  /// Magnifying glass — search.
  static const String search =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="21" cy="21" r="12"/>'
      '<path d="M30 30 L40 40"/>'
      '</svg>';

  /// Cog — settings.
  static const String settings =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="24" cy="24" r="6"/>'
      '<path d="M24 4 V10 M24 38 V44 M4 24 H10 M38 24 H44 '
      'M10 10 L14 14 M34 34 L38 38 M10 38 L14 34 M34 14 L38 10"/>'
      '</svg>';

  // ---------------------------------------------------------------------
  // Transport
  // ---------------------------------------------------------------------

  /// Play triangle.
  static const String play =
      '<svg viewBox="0 0 48 48" fill="currentColor" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M14 8 L40 24 L14 40 Z"/>'
      '</svg>';

  /// Pause — two vertical bars.
  static const String pause =
      '<svg viewBox="0 0 48 48" fill="currentColor" xmlns="http://www.w3.org/2000/svg">'
      '<rect x="12" y="10" width="8" height="28" rx="1"/>'
      '<rect x="28" y="10" width="8" height="28" rx="1"/>'
      '</svg>';

  /// Resume — forward triangle in a circle.
  static const String resume =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '<circle cx="24" cy="24" r="18"/>'
      '<path d="M20 16 L32 24 L20 32 Z" fill="currentColor"/>'
      '</svg>';

  /// Finish — flag.
  static const String finish =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 6 V42"/>'
      '<path d="M12 10 H36 L32 18 L36 26 H12 Z" fill="currentColor"/>'
      '</svg>';

  /// Close / X.
  static const String close =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="3" '
      'stroke-linecap="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M12 12 L36 36 M36 12 L12 36"/>'
      '</svg>';

  // ---------------------------------------------------------------------
  // Renderer
  // ---------------------------------------------------------------------

  /// Renders an icon constant at [size] dp with the given [color].
  ///
  /// Both the stroke and fill in each SVG constant are set to
  /// `currentColor`, which `flutter_svg` resolves via a srcIn color filter.
  /// This means a single asset recolors for every state (idle/active/reward)
  /// without shipping multiple variants.
  static Widget render(
    String svg, {
    required Color color,
    double size = 24,
    String? semanticsLabel,
  }) {
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      semanticsLabel: semanticsLabel,
    );
  }
}
