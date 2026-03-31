import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'app_exception.dart';

class ErrorMapper {
  const ErrorMapper._();

  static AppException mapException(Object error) {
    if (error is supabase.PostgrestException) {
      return _mapPostgrestException(error);
    }
    if (error is supabase.AuthException) {
      return _mapAuthException(error);
    }
    if (error is AppException) {
      return error;
    }
    return NetworkException(error.toString());
  }

  static DatabaseException _mapPostgrestException(
    supabase.PostgrestException error,
  ) {
    return DatabaseException(error.message, code: error.code ?? 'unknown');
  }

  static AuthException _mapAuthException(supabase.AuthException error) {
    return AuthException(error.message, code: error.statusCode ?? 'unknown');
  }
}
