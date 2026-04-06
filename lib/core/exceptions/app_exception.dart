sealed class AppException implements Exception {
  const AppException(this.message);

  /// Internal message for developer logging. May contain sensitive details
  /// such as table names or SQL error codes. **Never display to users.**
  final String message;

  /// User-safe message suitable for display in the UI.
  /// Subclasses override this to provide appropriate fallback text.
  String get userMessage => 'Something went wrong. Please try again.';

  @override
  String toString() => '$runtimeType: $message';
}

class AuthException extends AppException {
  const AuthException(super.message, {required this.code});

  final String code;

  @override
  String get userMessage => 'Authentication error. Please log in again.';
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {required this.code});

  final String code;

  @override
  String get userMessage => 'Something went wrong. Please try again.';
}

class NetworkException extends AppException {
  const NetworkException(super.message);

  @override
  String get userMessage =>
      'No internet connection. Please check your network.';
}

class ValidationException extends AppException {
  const ValidationException(super.message, {required this.field});

  final String field;

  /// Validation messages are user-generated and safe to display.
  @override
  String get userMessage => message;
}
