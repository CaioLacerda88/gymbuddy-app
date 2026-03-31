sealed class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

class AuthException extends AppException {
  const AuthException(super.message, {required this.code});

  final String code;
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {required this.code});

  final String code;
}

class NetworkException extends AppException {
  const NetworkException(super.message);
}

class ValidationException extends AppException {
  const ValidationException(super.message, {required this.field});

  final String field;
}
