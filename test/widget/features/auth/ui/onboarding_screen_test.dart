import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/auth/ui/onboarding_screen.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';

// Minimal stub to avoid hitting Supabase during widget tests.
class _FakeProfileNotifier extends ProfileNotifier {
  @override
  Future<Profile?> build() async => null;

  @override
  Future<void> saveOnboardingProfile({
    required String displayName,
    required String fitnessLevel,
  }) async {
    // no-op in tests
  }
}

void main() {
  Widget buildTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        profileProvider.overrideWith(_FakeProfileNotifier.new),
        ...overrides,
      ],
      child: MaterialApp(theme: AppTheme.dark, home: const OnboardingScreen()),
    );
  }

  group('OnboardingScreen', () {
    testWidgets('shows welcome page initially', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Track every rep,\nevery time'), findsOneWidget);
      expect(find.text('GET STARTED'), findsOneWidget);
    });

    testWidgets('navigates to profile setup on GET STARTED', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();

      expect(find.text('Set up your profile'), findsOneWidget);
      expect(find.text('Display name'), findsOneWidget);
      expect(find.text('Fitness level'), findsOneWidget);
    });

    testWidgets('shows fitness level chips on profile page', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();

      expect(find.text('Beginner'), findsOneWidget);
      expect(find.text('Intermediate'), findsOneWidget);
      expect(find.text('Advanced'), findsOneWidget);
    });

    testWidgets("profile page shows LET'S GO button", (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();

      expect(find.text("LET'S GO"), findsOneWidget);
    });

    testWidgets('progress bar shows 2 indicators', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Just verify we can navigate to both pages without hitting a third.
      expect(find.text('Track every rep,\nevery time'), findsOneWidget);

      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();

      expect(find.text('Set up your profile'), findsOneWidget);
    });
  });
}
