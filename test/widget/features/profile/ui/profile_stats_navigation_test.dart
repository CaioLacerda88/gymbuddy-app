/// BUG-3: Profile stat card navigation.
///
/// Verifies that tapping the Workouts stat card navigates to `/home/history`
/// and tapping the PRs stat card navigates to `/records`.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gymbuddy_app/core/local_storage/hive_service.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/personal_records/providers/pr_providers.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';
import 'package:gymbuddy_app/features/profile/ui/profile_screen.dart';
import 'package:gymbuddy_app/features/workouts/providers/workout_history_providers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:gymbuddy_app/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Stubs
// ---------------------------------------------------------------------------

class _MockAuthRepository extends Mock implements AuthRepository {
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

class _FakeProfileNotifier extends AsyncNotifier<Profile?>
    implements ProfileNotifier {
  @override
  Future<Profile?> build() async => const Profile(
    id: 'user-001',
    displayName: 'Test User',
    weightUnit: 'kg',
    createdAt: null,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Helper — wraps ProfileScreen in a GoRouter with target routes
// ---------------------------------------------------------------------------

Widget _buildTestApp() {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, _) => const Scaffold(body: ProfileScreen()),
      ),
      GoRoute(
        path: '/home/history',
        name: 'history',
        builder: (context, _) =>
            const Scaffold(body: Center(child: Text('History Screen'))),
      ),
      GoRoute(
        path: '/records',
        name: 'records',
        builder: (context, _) =>
            const Scaffold(body: Center(child: Text('Records Screen'))),
      ),
      // Manage Data route (needed because profile screen references it).
      GoRoute(
        path: '/profile/manage-data',
        builder: (context, _) =>
            const Scaffold(body: Center(child: Text('Manage Data'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      profileProvider.overrideWith(_FakeProfileNotifier.new),
      authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
      workoutCountProvider.overrideWith((ref) => Future.value(5)),
      prCountProvider.overrideWith((ref) => Future.value(3)),
    ],
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.dark,
      routerConfig: router,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('profile_nav_test_');
    Hive.init(tempDir.path);
    await Hive.openBox<dynamic>(HiveService.userPrefs);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('BUG-3: Profile stat card navigation', () {
    testWidgets('tapping Workouts card navigates to /home/history', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump();

      // Tap the Workouts stat card.
      await tester.tap(find.text('Workouts'));
      await tester.pumpAndSettle();

      // History screen should be visible.
      expect(find.text('History Screen'), findsOneWidget);
    });

    testWidgets('tapping PRs card navigates to /records', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump();

      // Tap the PRs stat card.
      await tester.tap(find.text('PRs'));
      await tester.pumpAndSettle();

      // Records screen should be visible.
      expect(find.text('Records Screen'), findsOneWidget);
    });

    testWidgets('Member since card does NOT navigate (no onTap)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump();

      // Tap the Member since card — should NOT navigate anywhere.
      await tester.tap(find.text('Member since'));
      await tester.pumpAndSettle();

      // Still on the profile screen.
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}
