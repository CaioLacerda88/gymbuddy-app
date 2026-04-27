/// Widget tests for [FirstAwakeningOverlay] (Phase 18c).
///
/// Spec §13.4: 800ms total, no backdrop dim, IgnorePointer over the card,
/// lightImpact at t=0. Slow textDim → hotViolet ignition (no peak/settle
/// staging — this is a softer onboarding moment than rank-up).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/ui/overlays/first_awakening_overlay.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap(Widget child) =>
    TestMaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  group('FirstAwakeningOverlay', () {
    late int hapticLightCount;

    setUp(() {
      hapticLightCount = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate' &&
                call.arguments == 'HapticFeedbackType.lightImpact') {
              hapticLightCount += 1;
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('renders {BODY PART} AWAKENS copy', (tester) async {
      await tester.pumpWidget(
        _wrap(const FirstAwakeningOverlay(bodyPart: BodyPart.chest)),
      );
      await tester.pump();

      expect(find.textContaining('CHEST'), findsOneWidget);
      expect(find.textContaining('AWAKENS'), findsOneWidget);
    });

    testWidgets('lightImpact fires exactly once at t=0', (tester) async {
      await tester.pumpWidget(
        _wrap(const FirstAwakeningOverlay(bodyPart: BodyPart.legs)),
      );
      await tester.pump();
      expect(hapticLightCount, 1);
      await tester.pump(const Duration(milliseconds: 800));
      expect(hapticLightCount, 1);
    });

    testWidgets('renders an IgnorePointer over the card', (tester) async {
      // Spec §13.4: no tap dismissal — the 800ms window is shorter than
      // typical reaction time, so an intentional tap shouldn't be possible.
      await tester.pumpWidget(
        _wrap(const FirstAwakeningOverlay(bodyPart: BodyPart.back)),
      );
      await tester.pump();
      expect(find.byType(IgnorePointer), findsWidgets);
    });

    testWidgets('does NOT render a full-screen dim backdrop', (tester) async {
      // 800ms is too short to dim and recover eyes; spec forbids backdrop.
      await tester.pumpWidget(
        _wrap(const FirstAwakeningOverlay(bodyPart: BodyPart.shoulders)),
      );
      await tester.pump();
      expect(find.byType(Positioned), findsNothing);
    });

    testWidgets('runs to completion without leaking tickers', (tester) async {
      await tester.pumpWidget(
        _wrap(const FirstAwakeningOverlay(bodyPart: BodyPart.core)),
      );
      await tester.pump();
      // Full 800ms window, plus a 200ms tail for the fade-out.
      await tester.pump(const Duration(milliseconds: 1000));

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      await tester.pump();
      expect(find.byType(FirstAwakeningOverlay), findsNothing);
    });
  });
}
