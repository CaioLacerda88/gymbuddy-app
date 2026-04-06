import 'dart:async';

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
/// A one-shot 10-second timer prevents the app from hanging on the splash
/// screen if the Supabase auth stream never emits its initial event (observed
/// in CI headless Chrome). Once any real event arrives, the timer is cancelled
/// and all subsequent events flow through normally.
final authStateProvider = StreamProvider<AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final controller = StreamController<AuthState>();

  var hasEmitted = false;
  final fallbackTimer = Timer(const Duration(seconds: 10), () {
    if (!hasEmitted && !controller.isClosed) {
      controller.add(const AuthState(AuthChangeEvent.signedOut, null));
    }
  });

  final subscription = repo.onAuthStateChange().listen(
    (event) {
      hasEmitted = true;
      fallbackTimer.cancel();
      if (!controller.isClosed) controller.add(event);
    },
    onError: (Object e, StackTrace s) {
      if (!controller.isClosed) controller.addError(e, s);
    },
    onDone: () {
      fallbackTimer.cancel();
      if (!controller.isClosed) controller.close();
    },
  );

  ref.onDispose(() {
    fallbackTimer.cancel();
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});
