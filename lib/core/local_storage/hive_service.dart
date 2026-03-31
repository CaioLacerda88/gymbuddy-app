import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  const HiveService();

  static const String activeWorkout = 'active_workout';
  static const String offlineQueue = 'offline_queue';
  static const String userPrefs = 'user_prefs';

  Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>(activeWorkout),
      Hive.openBox<dynamic>(offlineQueue),
      Hive.openBox<dynamic>(userPrefs),
    ]);
  }

  Future<void> clearAll() async {
    await Future.wait([
      _clearIfOpen(activeWorkout),
      _clearIfOpen(offlineQueue),
      _clearIfOpen(userPrefs),
    ]);
  }

  Future<void> _clearIfOpen(String name) async {
    if (Hive.isBoxOpen(name)) {
      await Hive.box<dynamic>(name).clear();
    }
  }
}
