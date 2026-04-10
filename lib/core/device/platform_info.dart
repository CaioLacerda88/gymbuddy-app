import 'package:flutter/foundation.dart';

/// Returns the current platform as a short string: 'android', 'ios', 'web',
/// 'macos', 'windows', 'linux', 'fuchsia', or 'unknown'.
String currentPlatform() {
  if (kIsWeb) return 'web';
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

/// Cached app version string in "version+build" format.
///
/// Populated once at app boot by `initAppVersion()` (added in Task 7) reading
/// package_info_plus, or left null if not initialized. Callers should fall
/// back to null gracefully.
String? _cachedAppVersion;

/// Returns the cached app version, or null if `initAppVersion()` has not run.
String? currentAppVersion() => _cachedAppVersion;

/// Sets the cached app version. Call once at app boot.
void setAppVersion(String version) {
  _cachedAppVersion = version;
}
