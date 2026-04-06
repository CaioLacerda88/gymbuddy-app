import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

/// Provides the [AuthRepository] singleton.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(Supabase.instance.client.auth);
});

/// Exposes the current auth state as a stream.
/// Used by the router to decide redirects.
///
/// Includes a 10-second timeout so the app does not hang on the splash screen
/// if the Supabase auth stream fails to emit (e.g. network issues, CI
/// environments). On timeout, a synthetic "signed out" event is emitted.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.onAuthStateChange().timeout(
    const Duration(seconds: 10),
    onTimeout: (sink) {
      sink.add(const AuthState(AuthChangeEvent.signedOut, null));
    },
  );
});
