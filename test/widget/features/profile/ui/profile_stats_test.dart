import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';
import 'package:gymbuddy_app/features/profile/ui/profile_screen.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class MockAuthRepository extends Mock implements AuthRepository {
  @override
  supabase.User? get currentUser => supabase.User(
    id: 'user-001',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    email: 'test@example.com',
    createdAt: DateTime(2026).toIso8601String(),
  );
}

Widget _buildProfileScreen({
  required ProfileNotifier Function() profileNotifier,
  int workoutCount = 0,
  int prCount = 0,
}) {
  return ProviderScope(
    overrides: [
      profileProvider.overrideWith(profileNotifier),
      authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      workoutCountProvider.overrideWith((ref) => Future.value(workoutCount)),
      prCountProvider.overrideWith((ref) => Future.value(prCount)),
    ],
    child: MaterialApp(
      theme: AppTheme.dark,
      home: const Scaffold(body: ProfileScreen()),
    ),
  );
}

void main() {
  group('ProfileScreen stats section (UX-U06)', () {
    testWidgets('shows zero workout count, zero PR count, and member since', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildProfileScreen(
          profileNotifier: _FakeProfileNotifier.new,
          workoutCount: 0,
          prCount: 0,
        ),
      );

      await tester.pumpAndSettle();

      // Stats labels should be visible.
      expect(find.text('Workouts'), findsOneWidget);
      expect(find.text('PRs'), findsOneWidget);
      expect(find.text('Member since'), findsOneWidget);

      // Values should show "0" for empty data.
      expect(find.text('0'), findsNWidgets(2));

      // Member since should show the date.
      expect(find.text('Jan 2026'), findsOneWidget);
    });

    testWidgets('shows correct workout count when > 0', (tester) async {
      await tester.pumpWidget(
        _buildProfileScreen(
          profileNotifier: _FakeProfileNotifier.new,
          workoutCount: 42,
          prCount: 0,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('shows correct PR count when > 0', (tester) async {
      await tester.pumpWidget(
        _buildProfileScreen(
          profileNotifier: _FakeProfileNotifier.new,
          workoutCount: 0,
          prCount: 7,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);
    });

    testWidgets('shows "--" for member since while profile is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildProfileScreen(profileNotifier: _LoadingProfileNotifier.new),
      );

      // Do NOT call pumpAndSettle — profile stays in loading state.
      await tester.pump();

      expect(find.text('--'), findsOneWidget);
    });
  });
}

class _FakeProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async {
    return Profile(
      id: 'user-001',
      displayName: 'Test User',
      weightUnit: 'kg',
      createdAt: DateTime(2026, 1, 15),
    );
  }

  @override
  Future<void> saveOnboardingProfile({
    required String displayName,
    required String fitnessLevel,
    int trainingFrequencyPerWeek = 3,
  }) async {}

  @override
  Future<void> updateTrainingFrequency(int frequency) async {}

  @override
  Future<void> toggleWeightUnit() async {}
}

/// A profile notifier that stays in the loading state forever.
///
/// Uses a [Completer] that never completes (no pending timer) so that
/// the test framework does not complain about orphan timers.
class _LoadingProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() {
    return Completer<Profile?>().future;
  }

  @override
  Future<void> saveOnboardingProfile({
    required String displayName,
    required String fitnessLevel,
    int trainingFrequencyPerWeek = 3,
  }) async {}

  @override
  Future<void> updateTrainingFrequency(int frequency) async {}

  @override
  Future<void> toggleWeightUnit() async {}
}
