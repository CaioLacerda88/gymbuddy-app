import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Generic cache service for reading/writing JSON to Hive boxes.
///
/// All operations are safe: they log errors and never throw. This makes
/// the cache layer a best-effort fallback that cannot crash the app.
class CacheService {
  const CacheService();

  /// Reads a value from [boxName] at [key], deserializing via [fromJson].
  ///
  /// Returns `null` when the key is missing, the box is not open,
  /// or the stored JSON is corrupt.
  T? read<T>(String boxName, String key, T Function(dynamic) fromJson) {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        log(
          'Box "$boxName" is not open — returning null for key "$key"',
          name: 'CacheService',
        );
        return null;
      }
      final raw = Hive.box<dynamic>(boxName).get(key);
      if (raw == null) return null;
      if (raw is! String) return null;
      final decoded = jsonDecode(raw);
      return fromJson(decoded);
    } catch (e) {
      log(
        'Failed to read "$key" from "$boxName": $e',
        name: 'CacheService',
        level: 900,
      );
      return null;
    }
  }

  /// Writes [value] as a JSON string to [boxName] at [key].
  ///
  /// Logs errors but never throws.
  Future<void> write(String boxName, String key, dynamic value) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        log(
          'Box "$boxName" is not open — skipping write for key "$key"',
          name: 'CacheService',
        );
        return;
      }
      final encoded = jsonEncode(value);
      await Hive.box<dynamic>(boxName).put(key, encoded);
    } catch (e) {
      log(
        'Failed to write "$key" to "$boxName": $e',
        name: 'CacheService',
        level: 900,
      );
    }
  }

  /// Deletes [key] from [boxName].
  ///
  /// Logs errors but never throws.
  Future<void> delete(String boxName, String key) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        log(
          'Box "$boxName" is not open — skipping delete for key "$key"',
          name: 'CacheService',
        );
        return;
      }
      await Hive.box<dynamic>(boxName).delete(key);
    } catch (e) {
      log(
        'Failed to delete "$key" from "$boxName": $e',
        name: 'CacheService',
        level: 900,
      );
    }
  }

  /// Clears all entries in [boxName].
  ///
  /// Logs errors but never throws.
  Future<void> clearBox(String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        log(
          'Box "$boxName" is not open — skipping clearBox',
          name: 'CacheService',
        );
        return;
      }
      await Hive.box<dynamic>(boxName).clear();
    } catch (e) {
      log(
        'Failed to clear box "$boxName": $e',
        name: 'CacheService',
        level: 900,
      );
    }
  }
}

/// Provides a [CacheService] instance via Riverpod.
final cacheServiceProvider = Provider<CacheService>((ref) {
  return const CacheService();
});
