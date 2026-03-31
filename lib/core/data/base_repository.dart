import 'package:gymbuddy_app/core/exceptions/app_exception.dart';
import 'package:gymbuddy_app/core/exceptions/error_mapper.dart';

abstract class BaseRepository {
  const BaseRepository();

  /// Wraps a Supabase call and maps exceptions to [AppException] types.
  Future<T> mapException<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } catch (e) {
      throw ErrorMapper.mapException(e);
    }
  }
}
