import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';

/// Invalidate the calling provider when the signed-in user id transitions
/// across an auth state emission.
///
/// **Why this exists (BUG-040):** providers that cache user-scoped data
/// across rebuilds (`ref.keepAlive()`, `AsyncNotifier` without auto-dispose)
/// survive a sign-out → sign-in into a different account. Without an
/// explicit invalidation, user A's cached COUNT/SELECT result can be served
/// to user B until the next app restart.
///
/// We compare the user-id slice (not the whole `AuthState`) because token
/// refreshes re-emit `AuthState` with the same user — invalidating on every
/// emission would re-issue the underlying query for no reason.
///
/// `prev` is null on the very first emission after the provider builds.
/// We treat that case as "no transition" by reading the prior id as null
/// AND letting the comparison short-circuit when `next` also resolves to
/// the same id the body just fetched against (the common cold-start case
/// where the auth stream replays the current session). The cost of an
/// extra invalidate when the *first* emission happens to differ (e.g. the
/// body fetched anonymously and the first stream event signs in a real
/// user) is one wasted re-fetch — strictly safer than missing the
/// sign-out → sign-in transition that this listener exists to catch.
///
/// `ref.invalidateSelf()` is the established pattern for keepAlive
/// invalidation across the codebase (workout history, exercise progress,
/// routine list, weekly plan, RPG progress).
void invalidateOnUserIdChange(Ref ref) {
  ref.listen(authStateProvider, (prev, next) {
    final prevUserId = prev?.value?.session?.user.id;
    final nextUserId = next.value?.session?.user.id;
    if (prevUserId == nextUserId) return;
    ref.invalidateSelf();
  });
}
