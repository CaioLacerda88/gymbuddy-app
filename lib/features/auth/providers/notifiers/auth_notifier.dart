import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/auth_repository.dart';
import '../auth_providers.dart';

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
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, Session?>(
  AuthNotifier.new,
);
