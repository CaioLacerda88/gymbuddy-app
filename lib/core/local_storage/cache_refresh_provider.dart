import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../features/exercises/models/exercise.dart';
import '../../features/exercises/providers/exercise_providers.dart';
import '../../features/personal_records/models/personal_record.dart';
import '../../features/personal_records/providers/pr_providers.dart';
import '../../features/routines/models/routine.dart';
import '../../features/routines/providers/routine_providers.dart';
import '../../features/workouts/models/workout.dart';
import '../../features/workouts/providers/workout_providers.dart';
import '../connectivity/connectivity_provider.dart';
import '../l10n/locale_provider.dart';

/// Triggers background cache refresh on app open for authenticated users.
///
/// When the user opens the app online, this provider pre-warms caches
/// for exercises, routines, personal records, and workout history so
/// subsequent navigations can hit local cache when offline.
///
/// Phase 15f: each repo call now takes the user's current locale so the
/// pre-warmed caches are written under locale-prefixed keys. A locale
/// switch evicts these entries (`LocaleNotifier.setLocale`) and the next
/// app open / online tick re-warms with the new locale.
final cacheRefreshProvider = FutureProvider<void>((ref) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;

  final isOnline = ref.read(isOnlineProvider);
  if (!isOnline) return;

  final locale = ref.read(localeProvider).languageCode;
  final exerciseRepo = ref.read(exerciseRepositoryProvider);
  final routineRepo = ref.read(routineRepositoryProvider);
  final prRepo = ref.read(prRepositoryProvider);
  final workoutRepo = ref.read(workoutRepositoryProvider);

  await Future.wait([
    exerciseRepo
        .getExercises(locale: locale, userId: userId)
        .catchError((_) => <Exercise>[]),
    routineRepo
        .getRoutines(userId: userId, locale: locale)
        .catchError((_) => <Routine>[]),
    prRepo
        .getRecordsForUser(userId: userId, locale: locale)
        .catchError((_) => <PersonalRecord>[]),
    workoutRepo
        .getWorkoutHistory(userId, locale: locale, limit: 50)
        .catchError((_) => <Workout>[]),
  ]);
});
