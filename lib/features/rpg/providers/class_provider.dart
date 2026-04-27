import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stub for the derived character class (Phase 18b).
///
/// Real class derivation lands in Phase 18e (spec §9.2): given the user's
/// per-body-part rank distribution, resolve to one of Initiate / Berserker /
/// Bulwark / Sentinel / Pathfinder / Atlas / Anchor / Ascendant. Until then
/// this provider returns `null` and the character sheet renders the placeholder
/// copy "The iron will name you." in the class-badge slot.
///
/// **Why null and not "Initiate":** the kickoff brief explicitly rejected an
/// "Initiate" default — it reads as a finished state ("I'm an Initiate") when
/// the real intent is "your class is yet to emerge." The placeholder copy
/// communicates pre-class-emergence; the badge transitions to a real label
/// the moment 18e ships, with no schema change required.
final characterClassProvider = Provider<String?>((ref) => null);
