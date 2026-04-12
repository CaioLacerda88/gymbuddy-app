import 'package:flutter_riverpod/legacy.dart';

/// Tracks post-signup state: the email that needs confirmation.
/// Null means no pending signup confirmation.
final signupPendingEmailProvider = StateProvider<String?>((ref) => null);
