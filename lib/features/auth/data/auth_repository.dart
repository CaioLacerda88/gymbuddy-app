import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/base_repository.dart';

class AuthRepository extends BaseRepository {
  const AuthRepository(this._auth);

  final GoTrueClient _auth;

  /// Stream of auth state changes.
  Stream<AuthState> onAuthStateChange() => _auth.onAuthStateChange;

  /// Current session, if any.
  Session? get currentSession => _auth.currentSession;

  /// Current user, if any.
  User? get currentUser => _auth.currentUser;

  /// Sign up with email and password.
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) {
    return mapException(() => _auth.signUp(email: email, password: password));
  }

  /// Sign in with email and password.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) {
    return mapException(
      () => _auth.signInWithPassword(email: email, password: password),
    );
  }

  /// Sign in with Google OAuth.
  Future<bool> signInWithGoogle() {
    return mapException(
      () => _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.gymbuddy://login-callback/',
      ),
    );
  }

  /// Sign out the current user.
  Future<void> signOut() {
    return mapException(() => _auth.signOut());
  }

  /// Resend the confirmation email to the given address.
  Future<void> resendConfirmationEmail(String email) {
    return mapException(() => _auth.resend(type: OtpType.signup, email: email));
  }

  /// Send a password reset email.
  Future<void> resetPassword(String email) {
    return mapException(() => _auth.resetPasswordForEmail(email));
  }

  /// Refresh the current session token.
  Future<AuthResponse> refreshSession() {
    return mapException(() => _auth.refreshSession());
  }
}
