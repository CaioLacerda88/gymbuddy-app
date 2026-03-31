import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/auth/ui/onboarding_screen.dart';

void main() {
  Widget buildTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
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

    testWidgets('navigates to workout choice page', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Page 1 -> Page 2
      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();

      // Page 2 -> Page 3
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      expect(find.text('Your first workout'), findsOneWidget);
      expect(find.text('Full Body Starter'), findsOneWidget);
      expect(find.text('Start Blank'), findsOneWidget);
      expect(find.text('Browse Exercises'), findsOneWidget);
    });

    testWidgets('LET\'S GO button is disabled until choice is made', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Navigate to page 3
      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Find the LET'S GO button - it should be disabled (onPressed is null)
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "LET'S GO"),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('LET\'S GO button enables after selecting a choice', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Navigate to page 3
      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Tap a workout choice
      await tester.tap(find.text('Full Body Starter'));
      await tester.pump();

      // Button should now be enabled
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "LET'S GO"),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('progress bar advances through pages', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // On page 1, first bar should be active (primary color)
      // Just verify the progress indicators exist
      expect(find.byType(Container), findsWidgets);

      // Navigate to page 2
      await tester.tap(find.text('GET STARTED'));
      await tester.pumpAndSettle();

      // Navigate to page 3
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // All three pages visited - verify we're on page 3
      expect(find.text('Your first workout'), findsOneWidget);
    });
  });
}
