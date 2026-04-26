/// Widget tests for [ClassBadge] (Phase 18b).
///
/// The kickoff lock requires the slot to ALWAYS render — even when the user
/// has no class — with the placeholder copy "The iron will name you." (en).
/// Once class derivation lands in 18e, the slot transitions to the real label
/// without a schema or layout change.
///
/// Tests:
///   1. Stub state (className == null) renders the placeholder copy.
///   2. Empty-string className treats as stub.
///   3. Real class name renders verbatim.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/ui/widgets/class_badge.dart';

import '../../../../helpers/test_material_app.dart';

Widget _wrap(String? className) {
  return TestMaterialApp(
    home: Scaffold(
      body: Center(child: ClassBadge(className: className)),
    ),
  );
}

void main() {
  group('ClassBadge', () {
    testWidgets('null className renders the placeholder copy', (tester) async {
      await tester.pumpWidget(_wrap(null));
      await tester.pump();

      expect(find.text('The iron will name you.'), findsOneWidget);
    });

    testWidgets('empty className is treated as stub', (tester) async {
      await tester.pumpWidget(_wrap(''));
      await tester.pump();

      expect(find.text('The iron will name you.'), findsOneWidget);
    });

    testWidgets('real class name renders verbatim', (tester) async {
      await tester.pumpWidget(_wrap('Bulwark'));
      await tester.pump();

      expect(find.text('Bulwark'), findsOneWidget);
      expect(find.text('The iron will name you.'), findsNothing);
    });
  });
}
