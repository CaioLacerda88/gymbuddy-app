import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/auth/providers/signup_state_provider.dart';
import 'package:gymbuddy_app/features/auth/ui/email_confirmation_screen.dart';

void main() {
  Widget buildTestWidget({String? email}) {
    return ProviderScope(
      overrides: [
        if (email != null)
          signupPendingEmailProvider.overrideWith((ref) => email),
      ],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: const EmailConfirmationScreen(),
      ),
    );
  }

  group('EmailConfirmationScreen', () {
    testWidgets('shows check inbox message and instructions', (tester) async {
      await tester.pumpWidget(buildTestWidget(email: 'test@example.com'));

      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.text('We sent a confirmation email to'), findsOneWidget);
    });

    testWidgets('shows email-specific sent-to text', (tester) async {
      await tester.pumpWidget(buildTestWidget(email: 'user@gym.com'));

      expect(find.text('user@gym.com'), findsOneWidget);
    });

    testWidgets('shows action buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget(email: 'test@example.com'));

      expect(find.text('BACK TO LOGIN'), findsOneWidget);
      expect(find.text("Didn't receive it? Resend email"), findsOneWidget);
    });
  });
}
