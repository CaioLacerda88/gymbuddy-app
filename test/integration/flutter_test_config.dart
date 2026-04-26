import 'dart:async';

/// Integration-test config.
///
/// Deliberately does NOT call TestWidgetsFlutterBinding.ensureInitialized() —
/// integration tests make real HTTP calls to local Supabase and must not have
/// the Flutter test binding intercept network requests.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await testMain();
}
