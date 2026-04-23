import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:repsaga/features/gamification/domain/xp_calculator.dart';
import 'package:repsaga/features/gamification/providers/xp_provider.dart';
import 'package:repsaga/features/gamification/ui/saga_intro_overlay.dart';

import '../../../helpers/test_material_app.dart';

void main() {
  group('SagaIntroOverlay', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('saga_intro_test_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>('user_prefs');
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    testWidgets('renders step 1 with NEXT button and no BEGIN', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(home: SagaIntroOverlay(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR TRAINING IS YOUR CHARACTER'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.text('BEGIN'), findsNothing);
    });

    testWidgets('tapping NEXT advances to step 2', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(home: SagaIntroOverlay(onDismiss: () {})),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      expect(find.text('XP FROM EVERY SET, PR, QUEST'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
    });

    testWidgets(
      'tapping NEXT twice reaches step 3 which shows BEGIN (not NEXT)',
      (tester) async {
        await tester.pumpWidget(
          TestMaterialApp(home: SagaIntroOverlay(onDismiss: () {})),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('NEXT'));
        await tester.pumpAndSettle();

        expect(find.textContaining('LVL 1'), findsOneWidget);
        expect(find.text('BEGIN'), findsOneWidget);
        expect(find.text('NEXT'), findsNothing);
      },
    );

    testWidgets('tapping BEGIN on step 3 fires onDismiss exactly once', (
      tester,
    ) async {
      var dismissed = 0;
      await tester.pumpWidget(
        TestMaterialApp(
          home: SagaIntroOverlay(onDismiss: () => dismissed += 1),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BEGIN'));
      await tester.pumpAndSettle();

      expect(dismissed, 1);
    });

    testWidgets('step 3 renders the user-specific LVL + rank label', (
      tester,
    ) async {
      await tester.pumpWidget(
        TestMaterialApp(
          home: SagaIntroOverlay(
            onDismiss: () {},
            startingLevel: 8,
            startingRank: Rank.iron,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Step-3 headline format: "LVL {n} — {RANK}"
      expect(find.textContaining('LVL 8'), findsOneWidget);
      expect(find.textContaining('IRON'), findsOneWidget);
    });
  });

  group('hasSeenSagaIntroForUser / markSagaIntroSeenForUser', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('saga_intro_pref_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>('user_prefs');
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('hasSeenSagaIntroForUser defaults to false for an untouched user', () {
      expect(hasSeenSagaIntroForUser('user-abc'), isFalse);
    });

    test(
      'markSagaIntroSeenForUser flips the flag for that user only',
      () async {
        await markSagaIntroSeenForUser('user-abc');
        expect(hasSeenSagaIntroForUser('user-abc'), isTrue);
        expect(hasSeenSagaIntroForUser('user-xyz'), isFalse);
      },
    );

    test('a second launch after dismiss still reports true '
        '(persistence across provider re-reads)', () async {
      await markSagaIntroSeenForUser('user-abc');
      // Simulate a "second launch" by re-checking. Hive is backed by the
      // same temp box, so the flag must persist.
      expect(hasSeenSagaIntroForUser('user-abc'), isTrue);
    });
  });

  group('hasRunRetroForUser', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('saga_retro_flag_');
      Hive.init(tempDir.path);
      await Hive.openBox<dynamic>('user_prefs');
    });

    tearDown(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('defaults to false for an untouched user', () {
      expect(hasRunRetroForUser('user-001'), isFalse);
    });
  });
}
