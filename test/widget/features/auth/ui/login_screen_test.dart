import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/auth/ui/login_screen.dart';

void main() {
  Widget buildTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(theme: AppTheme.dark, home: const LoginScreen()),
    );
  }

  group('LoginScreen', () {
    testWidgets('shows email and password fields', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows LOG IN button by default', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('LOG IN'), findsOneWidget);
    });

    testWidgets('toggles to sign up mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Tap the toggle button
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

      expect(find.text('SIGN UP'), findsOneWidget);
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('toggles back to login mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Toggle to sign up
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

      // Toggle back
      await tester.tap(find.text('Already have an account? Log in'));
      await tester.pump();

      expect(find.text('LOG IN'), findsOneWidget);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('validates empty email', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('LOG IN'));
      await tester.pump();

      expect(find.text('Email is required'), findsOneWidget);
    });

    testWidgets('validates invalid email', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextFormField).first, 'notanemail');
      await tester.tap(find.text('LOG IN'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('validates empty password', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
      await tester.tap(find.text('LOG IN'));
      await tester.pump();

      expect(find.text('Password is required'), findsOneWidget);
    });

    testWidgets('validates short password', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
      await tester.enterText(find.byType(TextFormField).last, '12345');
      await tester.tap(find.text('LOG IN'));
      await tester.pump();

      expect(
        find.text('Password must be at least 6 characters'),
        findsOneWidget,
      );
    });

    testWidgets('shows Google sign in button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('shows GymBuddy header', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('GymBuddy'), findsOneWidget);
    });
  });
}
