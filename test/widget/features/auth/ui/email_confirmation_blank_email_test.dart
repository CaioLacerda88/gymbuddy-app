import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/auth/providers/signup_state_provider.dart';
import 'package:gymbuddy_app/features/auth/ui/email_confirmation_screen.dart';

void main() {
  group('EmailConfirmationScreen blank email (PO-002)', () {
    testWidgets('shows email when signup email is available', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            signupPendingEmailProvider.overrideWith(
              (ref) => 'test@example.com',
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const EmailConfirmationScreen(),
          ),
        ),
      );

      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('We sent a confirmation email to'), findsOneWidget);
    });

    testWidgets('handles empty email gracefully after restart', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [signupPendingEmailProvider.overrideWith((ref) => null)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: const EmailConfirmationScreen(),
          ),
        ),
      );

      // Should not show the specific email line
      expect(find.text(''), findsNothing);
      // Should show a generic message instead
      expect(find.text('We sent you a confirmation email'), findsOneWidget);
    });
  });
}
