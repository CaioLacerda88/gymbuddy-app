import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  const HiveService();

  static const String activeWorkout = 'active_workout';
  static const String offlineQueue = 'offline_queue';
  static const String userPrefs = 'user_prefs';
  static const String exerciseCache = 'exercise_cache';
  static const String routineCache = 'routine_cache';
  static const String prCache = 'pr_cache';
  static const String workoutHistoryCache = 'workout_history_cache';
  static const String lastSetsCache = 'last_sets_cache';

  Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>(activeWorkout),
      Hive.openBox<dynamic>(offlineQueue),
      Hive.openBox<dynamic>(userPrefs),
      Hive.openBox<dynamic>(exerciseCache),
      Hive.openBox<dynamic>(routineCache),
      Hive.openBox<dynamic>(prCache),
      Hive.openBox<dynamic>(workoutHistoryCache),
      Hive.openBox<dynamic>(lastSetsCache),
    ]);
  }

  Future<void> clearAll() async {
    await Future.wait([
      _clearIfOpen(activeWorkout),
      _clearIfOpen(offlineQueue),
      _clearIfOpen(userPrefs),
      _clearIfOpen(exerciseCache),
      _clearIfOpen(routineCache),
      _clearIfOpen(prCache),
      _clearIfOpen(workoutHistoryCache),
      _clearIfOpen(lastSetsCache),
    ]);
  }

  Future<void> _clearIfOpen(String name) async {
    if (Hive.isBoxOpen(name)) {
      await Hive.box<dynamic>(name).clear();
    }
  }
}
