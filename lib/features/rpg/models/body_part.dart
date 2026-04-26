/// The six v1 strength tracks plus the v2 cardio track.
///
/// `dbValue` is the canonical token used in `body_part_progress.body_part`,
/// `xp_attribution` JSON keys, and `xp_events.attribution` payloads. Keep
/// these byte-for-byte aligned with PostgreSQL — any drift between Dart and
/// SQL means a backfill replay produces different rows than a live save.
///
/// `cardio` is in the enum so the schema, repositories, and UI plumbing all
/// accept it day one. v1 earns no XP from cardio; the constant
/// [activeBodyParts] excludes it from Character Level computation. Phase 18b+
/// flips `cardio` into `activeBodyParts` without a schema rework.
enum BodyPart {
  chest,
  back,
  legs,
  shoulders,
  arms,
  core,
  cardio;

  /// Token persisted in SQL and JSON. Lower-snake to match the spec §11.1
  /// CHECK contract (`body_part TEXT` literal values).
  String get dbValue => name;

  /// Reverse lookup. Returns null on unknown tokens so callers can decide
  /// whether to fail loudly (repositories) or fall back gracefully (UI
  /// reading legacy JSON).
  static BodyPart? tryFromDbValue(String value) {
    for (final bp in BodyPart.values) {
      if (bp.dbValue == value) return bp;
    }
    return null;
  }

  /// Throwing variant for repositories — a token we don't recognize is a
  /// data-integrity bug, not a UI fallback case.
  static BodyPart fromDbValue(String value) {
    final bp = tryFromDbValue(value);
    if (bp == null) {
      throw ArgumentError.value(value, 'body_part', 'unknown token');
    }
    return bp;
  }
}

/// The body parts that contribute to Character Level in v1 (six strength
/// tracks). Cardio (v2) is intentionally excluded — when v2 ships, this list
/// gains `BodyPart.cardio` and the denominator in
/// `characterLevel(...)` is unchanged.
const List<BodyPart> activeBodyParts = [
  BodyPart.chest,
  BodyPart.back,
  BodyPart.legs,
  BodyPart.shoulders,
  BodyPart.arms,
  BodyPart.core,
];
