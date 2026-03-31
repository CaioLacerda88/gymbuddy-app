import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HiveService {
  const HiveService._();

  static const String activeWorkout = 'active_workout';
  static const String offlineQueue = 'offline_queue';
  static const String userPrefs = 'user_prefs';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<dynamic>(activeWorkout),
      Hive.openBox<dynamic>(offlineQueue),
      Hive.openBox<dynamic>(userPrefs),
    ]);
  }

  static Future<void> clearAll() async {
    await Future.wait([
      Hive.box<dynamic>(activeWorkout).clear(),
      Hive.box<dynamic>(offlineQueue).clear(),
      Hive.box<dynamic>(userPrefs).clear(),
    ]);
  }
}

final hiveServiceProvider = Provider<HiveService>((ref) {
  return const HiveService._();
});
