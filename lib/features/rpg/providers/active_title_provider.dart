import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub for the user's currently equipped title (Phase 18b).
///
/// Phase 18c ships title detection, an `earned_titles` repository, and the
/// equip flow. Until then this provider returns `null` so the character sheet
/// can render the active-title pill slot conditionally without referencing
/// not-yet-built infrastructure. When 18c lands, this file is replaced by an
/// `AsyncNotifier<String?>` reading from `earned_titles` (where
/// `is_active = true`).
///
/// Returning `null` (not a "default" string) is deliberate — the slot is
/// hidden when no title is equipped per spec §13.1, and any "Initiate"-style
/// fallback would mis-read as a real-but-equipped title.
final activeTitleProvider = Provider<String?>((ref) => null);
