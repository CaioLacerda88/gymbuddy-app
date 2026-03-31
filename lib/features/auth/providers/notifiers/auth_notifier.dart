import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      return response.session;
    });
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.signInWithGoogle();
      // OAuth redirects externally; session comes via onAuthStateChange.
      return _repo.currentSession;
    });
  }

  Future<void> signOut() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _repo.signOut();
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
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, Session?>(
  AuthNotifier.new,
);
