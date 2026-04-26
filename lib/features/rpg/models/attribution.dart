/// `Attribution` (the validated value class) lives with the calculator that
/// consumes it, in `lib/features/rpg/domain/xp_distribution.dart`. This file
/// re-exports it under the `models/` path so callers that follow the
/// project's `feature/<x>/models/<x>.dart` import convention can find it.
library;

export '../domain/xp_distribution.dart' show Attribution;
