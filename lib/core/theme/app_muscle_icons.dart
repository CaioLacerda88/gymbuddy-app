/// Inline-SVG muscle-group icon set for RepSaga's Arcane Ascent direction
/// (§17.0c Polish Sprint 17.0d).
///
/// These glyphs replace the Material icons formerly returned by
/// [MuscleGroup.icon] and are rendered via [AppIcons.render] so one asset
/// recolors for every state. Authoring conventions match [AppIcons]:
///   * `viewBox="0 0 48 48"`
///   * `stroke="currentColor"` with `fill="none"` (monoline)
///   * `stroke-width="2.4"`, `stroke-linecap="round"`, `stroke-linejoin="round"`
///
/// Shape specs (from the 17.0d UI-UX audit):
///   * chest        — pectoral arch: mirrored convex curves meeting at sternum
///   * back         — trapezius V: inverted trapezoid, shoulder-bar + cervical
///   * legs         — quad sweep: two teardrop columns, splayed at the base
///   * shoulders    — deltoid arc over the top with two shoulder anchors
///   * arms         — biceps curl: shoulder circle + upper-arm + forearm
///   * core         — 2x3 ab grid inside a bounded torso frame
///   * cardio       — ECG trace: flat line with a narrow QRS spike
class AppMuscleIcons {
  const AppMuscleIcons._();

  /// Pectoral arch — two mirrored convex curves meeting at the sternum
  /// centerline. No arm, no head; reads as "parentheses joined at the top".
  static const String chest =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Left pec: sternum-top down to the side, bulging outward.
      '<path d="M24 10 C20 14 10 16 8 26 C8 34 14 38 20 36 C22 34 23 30 24 24"/>'
      // Right pec: mirror of the left.
      '<path d="M24 10 C28 14 38 16 40 26 C40 34 34 38 28 36 C26 34 25 30 24 24"/>'
      '</svg>';

  /// Trapezius V — wide inverted trapezoid. Diagonals converge from the
  /// shoulder points to the waist; horizontal shoulder-bar caps the top with
  /// a short cervical-notch stub.
  static const String back =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Shoulder bar + converging diagonals to the waist.
      '<path d="M8 10 H40"/>'
      '<path d="M8 10 L24 36 L40 10"/>'
      // Cervical-notch stub rising above the shoulder bar centerline.
      '<path d="M24 10 V6"/>'
      '</svg>';

  /// Quad sweep — two teardrop columns angled outward at the base. No knee,
  /// no foot; reads as "twin thigh slabs".
  static const String legs =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Left leg: narrows at the hip, widens slightly at the base.
      '<path d="M18 10 C14 18 12 28 14 38 C16 40 20 40 22 38 C22 28 20 18 18 10 Z"/>'
      // Right leg: mirror.
      '<path d="M30 10 C34 18 36 28 34 38 C32 40 28 40 26 38 C26 28 28 18 30 10 Z"/>'
      '</svg>';

  /// Deltoid arc — arc over the top from shoulder to shoulder with two
  /// short descending anchor lines at each endpoint.
  static const String shoulders =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Arc: left-shoulder up over the head and down to the right-shoulder.
      '<path d="M8 24 C8 14 16 8 24 8 C32 8 40 14 40 24"/>'
      // Short vertical anchors from each shoulder endpoint down to a body
      // plane at y:34.
      '<path d="M8 24 V34"/>'
      '<path d="M40 24 V34"/>'
      '</svg>';

  /// Biceps curl — user-callout posture: shoulder circle, upper-arm line,
  /// forearm angled up-right. Riffs off `AppIcons.hero` arm geometry minus
  /// the internal humerus line.
  static const String arms =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Shoulder circle. Geometry is shifted +6 on the x-axis versus the
      // original spec so the composite (shoulder + upper arm + forearm)
      // occupies x:14→38 inside the 48px frame and reads centered when
      // rendered alongside the other muscle glyphs at 24dp.
      '<circle cx="18" cy="10" r="4"/>'
      // Upper arm: shoulder to elbow.
      '<path d="M22 10 L26 28"/>'
      // Forearm: elbow to raised fist (biceps curl).
      '<path d="M26 28 L38 18"/>'
      '</svg>';

  /// Ab grid — 2x3 core block bounded by a vertical torso frame. Inner grid
  /// lines ship at a lighter 2.0 stroke so the frame reads as primary.
  static const String core =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      // Outer torso frame.
      '<path d="M16 10 H32 V38 H16 Z"/>'
      // Inner grid: two horizontals + central vertical (three rows by two
      // columns of ab segments). Stroke-2.0 so the frame stays dominant.
      '<path d="M16 19 H32 M16 28 H32 M24 10 V38" stroke-width="2"/>'
      '</svg>';

  /// ECG trace — flat baseline with a narrow QRS spike in the middle, reads
  /// as "heart rate / conditioning".
  static const String cardio =
      '<svg viewBox="0 0 48 48" fill="none" stroke="currentColor" stroke-width="2.4" '
      'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
      '<path d="M4 24 H16 L20 10 L24 36 L28 18 L32 24 H44"/>'
      '</svg>';
}
