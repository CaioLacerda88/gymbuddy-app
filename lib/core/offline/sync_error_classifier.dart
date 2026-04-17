import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Classifies sync errors as transient (retry-worthy) or terminal (give up).
///
/// Terminal errors are client-side mistakes (4xx) that will never succeed on
/// retry. Transient errors are server-side (5xx), network, or auth-token
/// issues that may resolve on their own.
abstract final class SyncErrorClassifier {
  static const _terminalCodes = {400, 403, 404, 409, 422};

  /// Returns `true` if [error] is a terminal error that should not be retried.
  static bool isTerminal(Object error) {
    if (error is supabase.PostgrestException) {
      final code = int.tryParse(error.code ?? '');
      return code != null && _terminalCodes.contains(code);
    }
    // Network, timeout, and auth-token errors are transient.
    if (error is SocketException) return false;
    if (error is TimeoutException) return false;
    if (error is supabase.AuthException) return false;
    // Unknown errors default to transient so the queue retries them.
    return false;
  }
}
