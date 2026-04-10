import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/device/platform_info.dart';
import '../../../../core/observability/sentry_report.dart';
import '../../../analytics/data/models/analytics_event.dart';
import '../../../analytics/providers/analytics_providers.dart';
import '../../../workouts/providers/workout_providers.dart';
import '../../data/auth_repository.dart';
import '../auth_providers.dart';
import '../signup_state_provider.dart';

/// Manages auth actions (sign in, sign up, sign out).
class AuthNotifier extends AsyncNotifier<Session?> {
  late AuthRepository _repo;

  @override
  FutureOr<Session?> build() {
    _repo = ref.watch(authRepositoryProvider);
    return _repo.currentSession;
  }

  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _repo.signUpWithEmail(
        email: email,
        password: password,
      );
      // If no session returned, email confirmation is required.
      if (response.session == null) {
        ref.read(signupPendingEmailProvider.notifier).state = email;
      }
      SentryReport.addBreadcrumb(category: 'auth', message: 'sign_up_email');
      return response.session;
    });
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final response = await _repo.signInWithEmail(
        email: email,
        password: password,
      );
      SentryReport.addBreadcrumb(category: 'auth', message: 'sign_in_email');
      return response.session;
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.signInWithGoogle();
      SentryReport.addBreadcrumb(category: 'auth', message: 'sign_in_google');
      // OAuth redirects externally; session comes via onAuthStateChange.
      return _repo.currentSession;
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.signOut();
      SentryReport.addBreadcrumb(category: 'auth', message: 'sign_out');
      return null;
    });
  }

  /// Resend the confirmation email for a pending signup.
  Future<void> resendConfirmationEmail(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.resendConfirmationEmail(email);
      return _repo.currentSession;
    });
  }

  /// Send a password reset email.
  Future<void> resetPassword(String email) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.resetPassword(email);
      return _repo.currentSession;
    });
  }

  /// Permanently delete the current user's account.
  ///
  /// Invokes the `delete-user` Edge Function via [AuthRepository]. On
  /// success the state transitions to [AsyncData] and a best-effort local
  /// sign-out is attempted to trigger the auth state listener redirect to
  /// the login screen. Sign-out errors after a successful delete are
  /// swallowed intentionally: the server has already invalidated the user,
  /// so surfacing "Failed to delete account" here would be catastrophically
  /// misleading (the account IS gone and the user cannot log in again).
  ///
  /// On delete failure, the state transitions to [AsyncError] with the
  /// wrapped [AppException] so the UI can surface a safe error message and
  /// the caller returns early before the sign-out attempt.
  Future<void> deleteAccount() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.deleteAccount();
      return null;
    });
    if (state.hasError) return;

    // Fire account_deleted BEFORE the sign-out so we still have a valid
    // session. This is the ONE analytics event we MUST await — the row has
    // to land before the CASCADE DELETE from auth.users drops it. The
    // try/catch wraps the await so a failed insert still allows deletion
    // to proceed.
    final user = _repo.currentUser;
    if (user != null) {
      // User.createdAt from gotrue is an ISO-8601 String, not a DateTime.
      final createdAt = DateTime.tryParse(user.createdAt);
      final daysSinceSignup = createdAt == null
          ? 0
          : DateTime.now().difference(createdAt).inDays;
      int workoutCount = 0;
      try {
        final workoutRepo = ref.read(workoutRepositoryProvider);
        workoutCount = await workoutRepo.getFinishedWorkoutCount(user.id);
      } catch (_) {
        // Best-effort — if we can't count, ship a 0.
      }
      try {
        await ref
            .read(analyticsRepositoryProvider)
            .insertEvent(
              userId: user.id,
              event: AnalyticsEvent.accountDeleted(
                workoutCount: workoutCount,
                daysSinceSignup: daysSinceSignup,
              ),
              platform: currentPlatform(),
              appVersion: currentAppVersion(),
            );
      } catch (_) {
        // Best-effort — never block deletion on analytics.
      }
      SentryReport.addBreadcrumb(category: 'auth', message: 'account_deleted');
    }

    // Account deleted successfully — best-effort local sign-out. Any error
    // here is ignored because the server-side user is already gone and the
    // auth state listener will handle the redirect regardless.
    try {
      await _repo.signOut();
    } catch (_) {
      // Intentionally swallowed: see doc comment above.
    }
    state = const AsyncData(null);
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, Session?>(
  AuthNotifier.new,
);
