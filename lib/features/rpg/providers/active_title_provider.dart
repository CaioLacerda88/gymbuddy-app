import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'earned_titles_provider.dart';

/// The slug of the user's currently equipped title, or null if no title is
/// active or the data is still loading.
///
/// This provider bridges the async [equippedTitleSlugProvider] into a
/// synchronous `String?` consumed by [characterSheetProvider] (which is a
/// pure-transform `Provider` rather than an `AsyncNotifier`). Using `.value`
/// on the `AsyncValue` means:
///   * `AsyncLoading` → null  (character sheet renders placeholder title slot)
///   * `AsyncData(null)` → null (no title equipped — slot hidden)
///   * `AsyncData("slug")` → "slug" (title pill rendered with localized name)
///   * `AsyncError` → null (graceful: title slot hidden on fetch failure)
///
/// **Invalidation:** callers that equip a title MUST call
/// `ref.invalidate(equippedTitleSlugProvider)` so this provider rebuilds
/// with fresh data. The active-workout equip flow in
/// `active_workout_screen.dart` already does this.
final activeTitleProvider = Provider<String?>((ref) {
  return ref.watch(equippedTitleSlugProvider).value;
});
