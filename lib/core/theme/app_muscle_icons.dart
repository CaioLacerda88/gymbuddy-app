/// Asset-backed muscle-group icon set for RepSaga's Arcane Ascent direction
/// (§17.0c Polish Sprint 17.0d, migrated to the silhouette pack in §17.0e).
///
/// Each constant is an asset path under `assets/icons/v3-silhouette/`
/// pointing at a Game-Icons.net SVG (CC BY 3.0 — Lorc + Delapouite). These
/// glyphs are surfaced via [MuscleGroup.svgIcon] and rendered through
/// `AppIcons.render` so a single asset recolors for every state.
///
/// Pack source mapping (see `assets/icons/COVERAGE.md`):
///   * chest     — `game-icons:breastplate` (swapped from the treasure-box
///                 `chest` glyph after the 2026-04-24 anatomy audit so the
///                 icon actually reads as pectoral plate)
///   * back      — `game-icons:back-pain`
///   * legs      — `game-icons:leg`
///   * shoulders — `game-icons:shoulder-armor`
///   * arms      — `game-icons:strong`
///   * core      — `game-icons:abdominal-armor`
///   * cardio    — `game-icons:heart-plus`
class AppMuscleIcons {
  const AppMuscleIcons._();

  static const String _root = 'assets/icons/v3-silhouette';

  /// Pectoral breastplate silhouette.
  static const String chest = '$_root/chest.svg';

  /// Back silhouette.
  static const String back = '$_root/back.svg';

  /// Leg silhouette.
  static const String legs = '$_root/legs.svg';

  /// Shoulder-armor silhouette.
  static const String shoulders = '$_root/shoulders.svg';

  /// Flexing-biceps silhouette (Game-Icons `strong`).
  static const String arms = '$_root/arms.svg';

  /// Abdominal-armor silhouette.
  static const String core = '$_root/core.svg';

  /// Heart-plus silhouette (cardio / conditioning).
  static const String cardio = '$_root/cardio.svg';
}
