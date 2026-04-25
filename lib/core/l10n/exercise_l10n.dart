import '../../l10n/app_localizations.dart';

/// Derives a slug from an English exercise name.
///
/// ```
/// exerciseSlug('Barbell Bench Press') == 'barbell_bench_press'
/// exerciseSlug("Farmer's Walk")       == 'farmer_s_walk'
/// ```
///
/// Slug derivation lives client-side because some legacy code paths and tests
/// still need to compute a slug from an English label without round-tripping
/// to the DB. Post-Phase-15f the canonical source of slugs is the
/// `exercises.slug` column populated by migration 00030.
String exerciseSlug(String englishName) {
  return englishName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

/// Returns the localized routine name for a default routine.
///
/// User-created routines return their original [name]. Default routines
/// are matched by exact English name; if there is no mapping the
/// original name is returned.
///
/// Routine names remain client-localized via ARB keys because routines are a
/// fixed catalogue of nine seeded entries, none of which are user-editable in
/// a per-locale way. Exercise names, in contrast, moved to DB-side
/// `exercise_translations` in Phase 15f to support 150+ entries plus
/// user-created exercises with locale-specific copy.
String localizedRoutineName({
  required String name,
  required bool isDefault,
  required AppLocalizations l10n,
}) {
  if (!isDefault) return name;
  final getter = _routineNames[name];
  return getter != null ? getter(l10n) : name;
}

// ---------------------------------------------------------------------------
// Routine name -> l10n getter map
// ---------------------------------------------------------------------------

typedef _L10nGetter = String Function(AppLocalizations);

const Map<String, _L10nGetter> _routineNames = {
  'Push Day': _routinePushDay,
  'Pull Day': _routinePullDay,
  'Leg Day': _routineLegDay,
  'Full Body': _routineFullBody,
  'Upper/Lower — Upper': _routineUpperLowerUpper,
  'Upper/Lower — Lower': _routineUpperLowerLower,
  '5x5 Strength': _routineFiveByFiveStrength,
  'Full Body Beginner': _routineFullBodyBeginner,
  'Arms & Abs': _routineArmsAndAbs,
};

String _routinePushDay(AppLocalizations l) => l.routineNamePushDay;
String _routinePullDay(AppLocalizations l) => l.routineNamePullDay;
String _routineLegDay(AppLocalizations l) => l.routineNameLegDay;
String _routineFullBody(AppLocalizations l) => l.routineNameFullBody;
String _routineUpperLowerUpper(AppLocalizations l) =>
    l.routineNameUpperLowerUpper;
String _routineUpperLowerLower(AppLocalizations l) =>
    l.routineNameUpperLowerLower;
String _routineFiveByFiveStrength(AppLocalizations l) =>
    l.routineNameFiveByFiveStrength;
String _routineFullBodyBeginner(AppLocalizations l) =>
    l.routineNameFullBodyBeginner;
String _routineArmsAndAbs(AppLocalizations l) => l.routineNameArmsAndAbs;
