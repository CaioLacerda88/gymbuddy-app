import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/features/auth/data/auth_repository.dart';
import 'package:gymbuddy_app/features/auth/providers/auth_providers.dart';
import 'package:gymbuddy_app/features/profile/models/profile.dart';
import 'package:gymbuddy_app/features/profile/providers/profile_providers.dart';
import 'package:gymbuddy_app/features/profile/ui/profile_screen.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockUser extends Mock implements User {}

class MockProfileNotifier extends AsyncNotifier<Profile?>
    with Mock
    implements ProfileNotifier {
  MockProfileNotifier(this._profile);
  final Profile? _profile;

  @override
  Future<Profile?> build() async => _profile;

  @override
  Future<void> toggleWeightUnit() async {}
}

Widget buildTestWidget({
  Profile? profile,
  String? email,
  MockAuthRepository? authRepository,
}) {
  final mockAuth = authRepository ?? MockAuthRepository();
  if (authRepository == null) {
    final mockUser = email != null ? (MockUser()..setEmail(email)) : null;
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockAuth.signOut()).thenAnswer((_) async {});
  }

  return ProviderScope(
    overrides: [
      profileProvider.overrideWith(() => MockProfileNotifier(profile)),
      authRepositoryProvider.overrideWithValue(mockAuth),
    ],
    child: MaterialApp(theme: AppTheme.dark, home: const ProfileScreen()),
  );
}

extension _MockUserEmail on MockUser {
  void setEmail(String email) {
    when(() => this.email).thenReturn(email);
  }
}

void main() {
  group('ProfileScreen', () {
    testWidgets('shows display name when profile has displayName', (
      tester,
    ) async {
      const profile = Profile(
        id: 'user-1',
        displayName: 'John Doe',
        weightUnit: 'kg',
      );

      await tester.pumpWidget(buildTestWidget(profile: profile));
      await tester.pump();

      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('shows fallback "Gym User" when displayName is null', (
      tester,
    ) async {
      const profile = Profile(id: 'user-1', weightUnit: 'kg');

      await tester.pumpWidget(buildTestWidget(profile: profile));
      await tester.pump();

      expect(find.text('Gym User'), findsOneWidget);
    });

    testWidgets('shows "Gym User" when profile is null', (tester) async {
      await tester.pumpWidget(buildTestWidget(profile: null));
      await tester.pump();

      expect(find.text('Gym User'), findsOneWidget);
    });

    testWidgets('shows email from auth repository', (tester) async {
      const profile = Profile(
        id: 'user-1',
        displayName: 'Jane',
        weightUnit: 'kg',
      );

      await tester.pumpWidget(
        buildTestWidget(profile: profile, email: 'jane@example.com'),
      );
      await tester.pump();

      expect(find.text('jane@example.com'), findsOneWidget);
    });

    testWidgets('shows weight unit segmented button', (tester) async {
      const profile = Profile(
        id: 'user-1',
        displayName: 'Jane',
        weightUnit: 'kg',
      );

      await tester.pumpWidget(buildTestWidget(profile: profile));
      await tester.pump();

      expect(find.byType(SegmentedButton<String>), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
      expect(find.text('lbs'), findsOneWidget);
    });

    testWidgets('kg is selected when weightUnit is kg', (tester) async {
      const profile = Profile(
        id: 'user-1',
        displayName: 'Jane',
        weightUnit: 'kg',
      );

      await tester.pumpWidget(buildTestWidget(profile: profile));
      await tester.pump();

      final button = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(button.selected, {'kg'});
    });

    testWidgets('lbs is selected when weightUnit is lbs', (tester) async {
      const profile = Profile(
        id: 'user-1',
        displayName: 'Jane',
        weightUnit: 'lbs',
      );

      await tester.pumpWidget(buildTestWidget(profile: profile));
      await tester.pump();

      final button = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(button.selected, {'lbs'});
    });

    testWidgets('shows logout button', (tester) async {
      await tester.pumpWidget(buildTestWidget(profile: null));
      await tester.pump();

      expect(find.text('Log Out'), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
    });

    testWidgets('logout button shows confirmation dialog', (tester) async {
      await tester.pumpWidget(buildTestWidget(profile: null));
      await tester.pump();

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      expect(find.text('Are you sure you want to log out?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('cancelling logout dialog does not call signOut', (
      tester,
    ) async {
      final mockAuth = MockAuthRepository();
      when(() => mockAuth.currentUser).thenReturn(null);
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await tester.pumpWidget(
        buildTestWidget(profile: null, authRepository: mockAuth),
      );
      await tester.pump();

      await tester.tap(find.text('Log Out'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => mockAuth.signOut());
    });

    testWidgets('shows person icon in CircleAvatar', (tester) async {
      await tester.pumpWidget(buildTestWidget(profile: null));
      await tester.pump();

      expect(find.byIcon(Icons.person), findsOneWidget);
    });
  });
}
