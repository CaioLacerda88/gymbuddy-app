import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/l10n/exercise_l10n.dart';
import 'package:repsaga/l10n/app_localizations.dart';
import 'package:repsaga/l10n/app_localizations_en.dart';
import 'package:repsaga/l10n/app_localizations_pt.dart';

void main() {
  group('exerciseSlug', () {
    test('converts simple name', () {
      expect(exerciseSlug('Deadlift'), 'deadlift');
    });

    test('converts multi-word name', () {
      expect(exerciseSlug('Barbell Bench Press'), 'barbell_bench_press');
    });

    test('converts hyphenated name', () {
      expect(exerciseSlug('Pull-Up'), 'pull_up');
    });

    test('converts name with apostrophe', () {
      expect(exerciseSlug("Farmer's Walk"), 'farmer_s_walk');
    });

    test('converts name with slash and em-dash', () {
      expect(exerciseSlug('Upper/Lower \u2014 Upper'), 'upper_lower_upper');
    });

    test('strips trailing underscores', () {
      expect(exerciseSlug('Plank '), 'plank');
    });

    test('strips leading underscores', () {
      expect(exerciseSlug(' Plank'), 'plank');
    });

    test('handles consecutive special chars', () {
      expect(exerciseSlug('Bench  Press'), 'bench_press');
    });
  });

  group('localizedExerciseName', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = AppLocalizationsEn();
    });

    test('returns original name for non-default exercises', () {
      expect(
        localizedExerciseName(
          name: 'My Custom Move',
          isDefault: false,
          l10n: l10n,
        ),
        'My Custom Move',
      );
    });

    test('returns original name when slug has no mapping', () {
      expect(
        localizedExerciseName(
          name: 'NonexistentExercise',
          isDefault: true,
          l10n: l10n,
        ),
        'NonexistentExercise',
      );
    });

    test('returns localized name for known default exercise', () {
      // English l10n should return the English name for Barbell Bench Press
      expect(
        localizedExerciseName(
          name: 'Barbell Bench Press',
          isDefault: true,
          l10n: l10n,
        ),
        'Barbell Bench Press',
      );
    });
  });

  group('localizedRoutineName', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = AppLocalizationsEn();
    });

    test('returns original name for non-default routines', () {
      expect(
        localizedRoutineName(
          name: 'My Custom Routine',
          isDefault: false,
          l10n: l10n,
        ),
        'My Custom Routine',
      );
    });

    test('returns localized name for known default routine', () {
      expect(
        localizedRoutineName(name: 'Push Day', isDefault: true, l10n: l10n),
        'Push Day',
      );
    });

    test('returns original name when no mapping exists', () {
      expect(
        localizedRoutineName(
          name: 'Unknown Routine Name',
          isDefault: true,
          l10n: l10n,
        ),
        'Unknown Routine Name',
      );
    });
  });

  group('localizedExerciseName (PT locale)', () {
    late AppLocalizations l10n;

    setUp(() {
      l10n = AppLocalizationsPt();
    });

    test('returns Portuguese name for known default exercise', () {
      expect(
        localizedExerciseName(
          name: 'Barbell Bench Press',
          isDefault: true,
          l10n: l10n,
        ),
        'Supino Reto com Barra',
      );
    });
  });
}
