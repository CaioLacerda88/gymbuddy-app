import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/base_repository.dart';

class AuthRepository extends BaseRepository {
  const AuthRepository(this._auth, {FunctionsClient? functions})
    : _injectedFunctions = functions;

  final GoTrueClient _auth;
  final FunctionsClient? _injectedFunctions;

  /// Functions client used for invoking Edge Functions. Tests can inject a
  /// mock via the constructor; in production we fall back to the global
  /// Supabase client's functions instance.
  FunctionsClient get _functions =>
      _injectedFunctions ?? Supabase.instance.client.functions;

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
        redirectTo: 'io.supabase.repsaga://login-callback/',
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

  /// Delete the current user's account permanently.
  ///
  /// Calls the `delete-user` Edge Function, which verifies the caller's JWT
  /// and then uses the service-role key to call `auth.admin.deleteUser()`.
  /// All user-owned rows in public tables cascade via FK constraints, so a
  /// single successful call removes the account and every piece of data
  /// tied to it. Before the delete, the Edge Function writes an anonymous
  /// row to `account_deletion_events` for churn analytics — [platform] and
  /// [appVersion] are forwarded so the audit row carries that context.
  /// Callers should follow up with [signOut] so the auth state listener
  /// can redirect to the login screen.
  Future<void> deleteAccount({String? platform, String? appVersion}) {
    return mapException(() async {
      // Use `if (x != null)` collection-if rather than the newer null-aware
      // map value syntax (`'platform': ?platform`): build_runner's bundled
      // analyzer on CI can't parse the latter, so the freezed/json_serializable
      // generators fail at the `auth_repository.dart` parse step.
      final response = await _functions.invoke(
        'delete-user',
        body: <String, dynamic>{
          // ignore: use_null_aware_elements
          if (platform != null) 'platform': platform,
          // ignore: use_null_aware_elements
          if (appVersion != null) 'app_version': appVersion,
        },
      );
      if (response.status >= 400) {
        throw Exception('Delete account failed (status ${response.status})');
      }
    });
  }
}
