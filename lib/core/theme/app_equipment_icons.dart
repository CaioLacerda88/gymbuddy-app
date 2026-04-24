/// Inline-SVG equipment icon set for RepSaga's Arcane Ascent direction
/// (§17.0c Polish Sprint 17.0d).
///
/// These glyphs replace the Material icons formerly returned by
/// [EquipmentType.icon] and are rendered via [AppIcons.render] so one asset
/// recolors for every state. Authoring conventions match [AppIcons]:
///   * `viewBox="0 0 48 48"`
///   * `stroke="currentColor"` with `fill="none"` (monoline)
///   * `stroke-width="2.4"`, `stroke-linecap="round"`, `stroke-linejoin="round"`
///
/// **Barbell intentionally omitted.** [EquipmentType.barbell] maps directly
/// to `AppIcons.lift` — that glyph is the app's signature constant and
/// shipping a second barbell would duplicate visual vocabulary.
///
/// Shape specs (from the 17.0d UI-UX audit):
///   * dumbbell   — side view: shaft with ONE plate each side (not two like
///                  the barbell, so the two glyphs read as distinct)
///   * cable      — pulley circle top-right, diagonal cable, grip rect bottom-left
///   * machine    — 4-plate weight stack between two vertical guide rails + pin
///   * bodyweight — stick figure in a "ready" stance (legs split, arms at 45°)
///   * bands      — flat ellipse loop with two horizontal crease lines
///   * kettlebell — semicircle handle + rounded trapezoid body, wider at base
class AppEquipmentIcons {
  const AppEquipmentIcons._();

  /// Side-view dumbbell — horizontal shaft with a single plate each side.
  /// One plate per side distinguishes this from [AppIcons.lift] (which has
  /// two asymmetric plates).
  static const String dumbbell =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Shaft.
      '<path d="M10 24 H38"/>'
      // Left plate.
      '<rect x="6" y="18" width="6" height="12" rx="1"/>'
      // Right plate.
      '<rect x="36" y="18" width="6" height="12" rx="1"/>'
      '</svg>';

  /// Cable station — top-right pulley, diagonal cable, bottom-left handle.
  static const String cable =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Pulley wheel.
      '<circle cx="36" cy="10" r="5"/>'
      // Cable running from the pulley tangent down to the handle.
      '<path d="M31 13 L12 38"/>'
      // Handle grip at the bottom-left.
      '<rect x="8" y="36" width="8" height="5" rx="2"/>'
      '</svg>';

  /// Weight-stack machine — 4 plates stacked between two vertical guide
  /// rails with a pin marker on the top plate.
  static const String machine =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Vertical guide rails.
      '<path d="M16 8 V40"/>'
      '<path d="M32 8 V40"/>'
      // 4-plate weight stack.
      '<rect x="18" y="10" width="12" height="5" rx="1"/>'
      '<rect x="18" y="18" width="12" height="5" rx="1"/>'
      '<rect x="18" y="26" width="12" height="5" rx="1"/>'
      '<rect x="18" y="34" width="12" height="5" rx="1"/>'
      // Pin indicating the selected weight.
      '<circle cx="24" cy="22" r="2" fill="currentColor"/>'
      '</svg>';

  /// Bodyweight — stick figure in a split-stance "ready" posture with arms
  /// raised at 45°. Not a yoga glyph; reads as "the user is the equipment".
  static const String bodyweight =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Head.
      '<circle cx="24" cy="9" r="5"/>'
      // Torso.
      '<path d="M24 14 V28"/>'
      // Legs: split stance down to each foot.
      '<path d="M24 28 L16 40"/>'
      '<path d="M24 28 L32 40"/>'
      // Arms at 45° from the shoulder.
      '<path d="M24 20 L14 14"/>'
      '<path d="M24 20 L34 14"/>'
      '</svg>';

  /// Resistance band — flat ellipse loop with two horizontal crease lines
  /// inside (reads as a stretched band under tension).
  static const String bands =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Loop outline.
      '<ellipse cx="24" cy="24" rx="18" ry="10"/>'
      // Inner crease lines (clipped visually by the ellipse; we stop short
      // of the ellipse edges so the crease reads as an interior ridge, not
      // an external line).
      '<path d="M10 20 H38" stroke-width="2"/>'
      '<path d="M10 28 H38" stroke-width="2"/>'
      '</svg>';

  /// Kettlebell — semicircle handle at the top connecting to a rounded
  /// trapezoid body that widens at the base.
  static const String kettlebell =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Handle: half-circle arc from the left shoulder over the top to the
      // right shoulder.
      '<path d="M16 18 A8 8 0 0 1 32 18"/>'
      // Body: rounded trapezoid, wider at the base.
      '<path d="M16 18 C14 24 14 32 16 36 C20 40 28 40 32 36 C34 32 34 24 32 18"/>'
      '</svg>';
}
