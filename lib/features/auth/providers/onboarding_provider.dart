import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the current user has completed onboarding.
/// This is set to true after signup and cleared after onboarding completes.
final needsOnboardingProvider = StateProvider<bool>((ref) => false);
