import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
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

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

      expect(find.text('SIGN UP'), findsOneWidget);
      expect(find.text('Create your account'), findsOneWidget);
    });

    testWidgets('toggles back to login mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

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

    testWidgets('validates email without domain extension', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(find.byType(TextFormField).first, 'user@domain');
      await tester.tap(find.text('LOG IN'));
      await tester.pump();

      expect(find.text('Enter a valid email'), findsOneWidget);
    });

    testWidgets('accepts valid email', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byType(TextFormField).first,
        'user@domain.com',
      );
      await tester.enterText(find.byType(TextFormField).last, '123456');
      await tester.tap(find.text('LOG IN'));
      await tester.pump();

      // No email validation error should appear
      expect(find.text('Enter a valid email'), findsNothing);
      expect(find.text('Email is required'), findsNothing);
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

    testWidgets('shows forgot password link in login mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('hides forgot password in signup mode', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets('shows password visibility toggle', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Password field should have a visibility toggle icon
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Initially obscured (visibility_off shown)
      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);

      // Tap to show password
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pump();

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);
    });

    testWidgets('forgot password shows error when email is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      // Should show inline error asking to enter email first
      expect(
        find.text('Enter your email above, then tap "Forgot password?"'),
        findsOneWidget,
      );
    });

    // PO-004: toggling login→signup must clear the password field so a user
    // cannot accidentally carry a password from one mode to the other.
    testWidgets('PO-004: toggling to sign-up mode clears the password field', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Type a password in login mode.
      await tester.enterText(find.byType(TextFormField).last, 'mySecret123');

      // Switch to sign-up mode.
      await tester.tap(find.text("Don't have an account? Sign up"));
      await tester.pump();

      // The password field must be empty after the toggle.
      final passwordField = tester.widget<EditableText>(
        find.descendant(
          of: find.byType(TextFormField).last,
          matching: find.byType(EditableText),
        ),
      );
      expect(passwordField.controller.text, isEmpty);
    });

    testWidgets(
      'PO-004: toggling back to login mode clears the password field',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Navigate to sign-up mode and enter a password.
        await tester.tap(find.text("Don't have an account? Sign up"));
        await tester.pump();
        await tester.enterText(find.byType(TextFormField).last, 'signupPass');

        // Switch back to login mode.
        await tester.tap(find.text('Already have an account? Log in'));
        await tester.pump();

        // The password field must be empty.
        final passwordField = tester.widget<EditableText>(
          find.descendant(
            of: find.byType(TextFormField).last,
            matching: find.byType(EditableText),
          ),
        );
        expect(passwordField.controller.text, isEmpty);
      },
    );

    testWidgets('shows legal links footer with Terms and Privacy buttons', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // The intro copy plus both link buttons must be present.
      expect(find.text('By continuing, you agree to our '), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('legal footer links are wired to TextButtons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump();

      // Both links must be tappable TextButtons (we don't assert navigation
      // here because the login test harness doesn't mount GoRouter).
      expect(
        find.ancestor(
          of: find.text('Terms of Service'),
          matching: find.byType(TextButton),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.text('Privacy Policy'),
          matching: find.byType(TextButton),
        ),
        findsOneWidget,
      );
    });
  });
}
