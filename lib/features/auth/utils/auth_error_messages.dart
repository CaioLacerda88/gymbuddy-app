/// Maps auth error codes/messages to user-friendly text.
class AuthErrorMessages {
  const AuthErrorMessages._();

  static String fromError(Object error) {
    final message = error.toString().toLowerCase();

    // Supabase auth error patterns
    if (message.contains('invalid login credentials') ||
        message.contains('invalid_credentials')) {
      return 'Wrong email or password. Please try again.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please check your inbox and confirm your email first.';
    }
    if (message.contains('user already registered') ||
        message.contains('already been registered')) {
      return 'An account with this email already exists. Try logging in instead.';
    }
    if (message.contains('email rate limit') ||
        message.contains('rate limit')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (message.contains('weak password') ||
        message.contains('password should be')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (message.contains('network') ||
        message.contains('socket') ||
        message.contains('connection')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (message.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    if (message.contains('otp') || message.contains('token')) {
      return 'The confirmation link has expired. Please request a new one.';
    }

    // Fallback
    return 'Something went wrong. Please try again.';
  }
}
