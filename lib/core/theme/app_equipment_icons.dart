/// Asset-backed equipment icon set for RepSaga's Arcane Ascent direction
/// (§17.0c Polish Sprint 17.0d, migrated to the silhouette pack in §17.0e).
///
/// Each constant is an asset path under `assets/icons/v3-silhouette/`
/// pointing at a Game-Icons.net SVG (CC BY 3.0 — Lorc + Delapouite) except
/// for [kettlebell] which falls back to MDI because game-icons has no
/// kettlebell in its vocabulary.
///
/// **Barbell intentionally omitted.** [EquipmentType.barbell] maps directly
/// to `AppIcons.lift` — that glyph is the app's signature constant and
/// shipping a second barbell would fork visual vocabulary for zero benefit.
///
/// Pack source mapping (see `assets/icons/COVERAGE.md`):
///   * dumbbell   — `game-icons:weight`
///   * cable      — `game-icons:rope-coil`
///   * machine    — `game-icons:pulley-hook`
///   * bodyweight — `game-icons:acrobatic`
///   * bands      — `game-icons:spring`
///   * kettlebell — `mdi:kettlebell` (fallback)
class AppEquipmentIcons {
  const AppEquipmentIcons._();

  static const String _root = 'assets/icons/v3-silhouette';

  /// Dumbbell / weight silhouette.
  static const String dumbbell = '$_root/dumbbell.svg';

  /// Coiled rope / cable silhouette.
  static const String cable = '$_root/cable.svg';

  /// Pulley hook — weight-stack machine stand-in.
  static const String machine = '$_root/machine.svg';

  /// Acrobatic pose — bodyweight exercises.
  static const String bodyweight = '$_root/bodyweight.svg';

  /// Coiled spring — resistance bands.
  static const String bands = '$_root/bands.svg';

  /// Kettlebell silhouette (MDI fallback — game-icons has none).
  static const String kettlebell = '$_root/kettlebell.svg';
}
