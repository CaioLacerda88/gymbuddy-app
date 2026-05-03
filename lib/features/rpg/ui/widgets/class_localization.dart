import '../../../../l10n/app_localizations.dart';
import '../../models/character_class.dart';

/// Localized display name + tagline for a single [CharacterClass] (BUG-016 / BUG-011).
///
/// **Why two pieces of copy per class:**
///   * `name` — the badge label (e.g. "Bulwark", "Baluarte"). Surfaced on
///     the character sheet's [`ClassBadge`] and as the headline of the
///     class-change overlay.
///   * `tagline` — short declarative phrase (e.g. "the pillar moves" /
///     "o pilar se move") used only by the class-change overlay's headline
///     composition. Lowercase by design — reads as a footnote beneath the
///     all-caps class name, not as a heading. PO brand-voice direction
///     (2026-05-02): masculine-emphatic, declarative, short, no passive.
///
/// **Why a switch and not a `Map<CharacterClass, …>`:** the switch is
/// exhaustive on the enum, so adding a new class (e.g. `wayfarer` in v2)
/// produces a compile error here until the case is filled in — preventing a
/// silent "unknown class" string from leaking to UI. Same rationale that
/// drove `localizedTitleCopy` and `localizedBodyPartName`.
///
/// **Why this lives in `widgets/`:** consumed by the badge and the overlay,
/// both presentation-layer. Keeping the lookup at the UI layer means the
/// resolver/repository stay l10n-free and the unit tests can assert against
/// either the slug or the localized string without standing up a localized
/// widget tree.
class ClassCopy {
  const ClassCopy({required this.name, required this.tagline});

  /// Localized display name (e.g. "Bulwark" / "Baluarte"). Already
  /// formatted in title-case per the ARB; the badge uppercases it via the
  /// font's letter-spacing rather than a string transform.
  final String name;

  /// Short declarative tagline (e.g. "the pillar moves" /
  /// "o pilar se move"). Lowercase by spec.
  final String tagline;
}

/// Resolve [cls] to its localized name + tagline.
ClassCopy localizedClassCopy(CharacterClass cls, AppLocalizations l10n) {
  return switch (cls) {
    CharacterClass.initiate => ClassCopy(
      name: l10n.classInitiate,
      tagline: l10n.classTaglineInitiate,
    ),
    CharacterClass.berserker => ClassCopy(
      name: l10n.classBerserker,
      tagline: l10n.classTaglineBerserker,
    ),
    CharacterClass.bulwark => ClassCopy(
      name: l10n.classBulwark,
      tagline: l10n.classTaglineBulwark,
    ),
    CharacterClass.sentinel => ClassCopy(
      name: l10n.classSentinel,
      tagline: l10n.classTaglineSentinel,
    ),
    CharacterClass.pathfinder => ClassCopy(
      name: l10n.classPathfinder,
      tagline: l10n.classTaglinePathfinder,
    ),
    CharacterClass.atlas => ClassCopy(
      name: l10n.classAtlas,
      tagline: l10n.classTaglineAtlas,
    ),
    CharacterClass.anchor => ClassCopy(
      name: l10n.classAnchor,
      tagline: l10n.classTaglineAnchor,
    ),
    CharacterClass.ascendant => ClassCopy(
      name: l10n.classAscendant,
      tagline: l10n.classTaglineAscendant,
    ),
  };
}

/// Convenience for callers that only need the localized class name (e.g.
/// the badge). Same as `localizedClassCopy(cls, l10n).name` but avoids
/// allocating a [ClassCopy] when the tagline isn't used.
String localizedClassName(CharacterClass cls, AppLocalizations l10n) {
  return switch (cls) {
    CharacterClass.initiate => l10n.classInitiate,
    CharacterClass.berserker => l10n.classBerserker,
    CharacterClass.bulwark => l10n.classBulwark,
    CharacterClass.sentinel => l10n.classSentinel,
    CharacterClass.pathfinder => l10n.classPathfinder,
    CharacterClass.atlas => l10n.classAtlas,
    CharacterClass.anchor => l10n.classAnchor,
    CharacterClass.ascendant => l10n.classAscendant,
  };
}
