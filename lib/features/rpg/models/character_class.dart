import 'body_part.dart';

/// The eight v1 character classes (spec §9).
///
/// Class is **derived** from the user's per-body-part Rank distribution and is
/// purely cosmetic — no XP modifiers, no content gates, no mechanical effects.
/// Resolution lives in [`class_resolver.dart`](../domain/class_resolver.dart);
/// this enum is the typed result the resolver returns and the badge consumes.
///
/// **Why an enum and not a Freezed sealed union:** every class is a single
/// value with no per-variant payload — slug + l10n key are pure functions of
/// the variant. An enum gives us exhaustive `switch` on the resolver consumers
/// (the badge, post-workout celebration overlay) at zero allocation cost. A
/// sealed union would buy nothing but boilerplate.
///
/// **Wayfarer (cardio specialist) is not in this enum.** Cardio is v2;
/// `activeBodyParts` excludes [BodyPart.cardio] in v1 so the resolver can
/// never see a cardio-dominant rank distribution. When v2 ships, add a
/// `Wayfarer` variant + slug + dominant-body-part lookup entry — no other
/// surface has to change.
enum CharacterClass {
  /// Newcomer — every active rank ≤ 4. The default state for fresh users
  /// and the only class that does not require any body part above rank 5.
  initiate('initiate'),

  /// Arms-dominant. Bicep / tricep specialist.
  berserker('berserker'),

  /// Chest-dominant. Pressing specialist.
  bulwark('bulwark'),

  /// Back-dominant. Pulling specialist.
  sentinel('sentinel'),

  /// Legs-dominant. Lower-body specialist.
  pathfinder('pathfinder'),

  /// Shoulders-dominant. Overhead / yoke specialist.
  atlas('atlas'),

  /// Core-dominant. Stability / midline specialist.
  anchor('anchor'),

  /// Balanced — every rank within 30% of the max AND min ≥ 5. Rare and
  /// prestigious; takes precedence over the dominant-class lookup.
  ascendant('ascendant');

  const CharacterClass(this.slug);

  /// Stable identifier used as the localization key suffix (`class_{slug}`)
  /// and the shareable string token. Persists across editorial copy revisions
  /// — renaming a class would orphan persisted shareable cards if added later.
  final String slug;

  /// L10n key for the class display name (`class_initiate`, `class_berserker`,
  /// …). Resolved against [`AppLocalizations`] at the badge layer; the model
  /// never holds localized strings.
  String get l10nKey => 'class_$slug';
}
