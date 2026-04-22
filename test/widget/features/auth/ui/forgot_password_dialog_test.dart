import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/auth/ui/login_screen.dart';
import '../../../../helpers/test_material_app.dart';

void main() {
  Widget buildTestWidget() {
    return ProviderScope(
      child: TestMaterialApp(theme: AppTheme.dark, home: const LoginScreen()),
    );
  }

  group('Forgot password confirmation dialog (QA-006)', () {
    testWidgets('shows confirmation dialog when email is provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Enter email
      await tester.enterText(
        find.byType(TextFormField).first,
        'user@example.com',
      );
      await tester.pump();

      // Tap forgot password
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Reset Password'), findsOneWidget);
      expect(
        find.text('Send a password reset email to user@example.com?'),
        findsOneWidget,
      );
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Send Reset Email'), findsOneWidget);
    });

    testWidgets('cancel dismisses the dialog without sending', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.enterText(
        find.byType(TextFormField).first,
        'user@example.com',
      );
      await tester.pump();

      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      // Cancel the dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Dialog should be dismissed
      expect(find.text('Reset Password'), findsNothing);
    });

    testWidgets('shows inline error when email is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      // Should show inline error, not dialog
      expect(find.text('Reset Password'), findsNothing);
      expect(
        find.text('Enter your email above, then tap "Forgot password?"'),
        findsOneWidget,
      );
    });
  });
}
