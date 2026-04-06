import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/exceptions/app_exception.dart';
import 'error_overlay.dart';

class AsyncValueBuilder<T> extends StatelessWidget {
  const AsyncValueBuilder({
    super.key,
    required this.value,
    required this.data,
    this.loading,
    this.error,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget Function()? loading;
  final Widget Function(Object error, StackTrace? stackTrace)? error;

  /// Returns a user-safe message from an error object.
  ///
  /// If the error is an [AppException], uses [AppException.userMessage].
  /// Otherwise logs the raw error and returns a generic message.
  static String safeErrorMessage(Object err) {
    if (err is AppException) return err.userMessage;
    debugPrint('[AsyncValueBuilder] Unexpected error: $err');
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading:
          loading ?? () => const Center(child: CircularProgressIndicator()),
      error:
          error ?? (err, stack) => ErrorOverlay(message: safeErrorMessage(err)),
    );
  }
}
