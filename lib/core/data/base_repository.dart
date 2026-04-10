import 'dart:async';

import 'package:gymbuddy_app/core/exceptions/app_exception.dart';
import 'package:gymbuddy_app/core/exceptions/error_mapper.dart';
import 'package:gymbuddy_app/core/observability/sentry_report.dart';

abstract class BaseRepository {
  const BaseRepository();

  /// Wraps a Supabase call and maps exceptions to [AppException] types.
  ///
  /// [AppException]s are rethrown unchanged (they are expected domain errors
  /// — double-reporting them to Sentry would flood the tracker). Unexpected
  /// errors (raw Supabase/network/system) are fire-and-forget captured to
  /// Sentry before being mapped and thrown as an AppException subclass.
  Future<T> mapException<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppException {
      rethrow;
    } catch (e, st) {
      unawaited(SentryReport.captureException(e, stackTrace: st));
      throw ErrorMapper.mapException(e);
    }
  }
}
