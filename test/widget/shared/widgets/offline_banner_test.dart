import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/shared/widgets/offline_banner.dart';

void main() {
  group('OfflineBanner', () {
    Widget buildSubject() {
      return const MaterialApp(home: Scaffold(body: OfflineBanner()));
    }

    testWidgets('renders "Offline" text', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.textContaining('Offline'), findsOneWidget);
    });

    testWidgets('renders cloud_off icon', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    });

    testWidgets('uses errorContainer background color', (tester) async {
      await tester.pumpWidget(buildSubject());

      final container = tester.widget<Container>(find.byType(Container));
      final decoration = container.color;
      final context = tester.element(find.byType(OfflineBanner));
      final expectedColor = Theme.of(context).colorScheme.errorContainer;

      expect(decoration, expectedColor);
    });

    testWidgets('renders exact offline message copy', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.text("Offline \u2014 changes will sync when you're back online"),
        findsOneWidget,
      );
    });

    testWidgets('uses vertical padding for text scaling', (tester) async {
      await tester.pumpWidget(buildSubject());

      final container = tester.widget<Container>(find.byType(Container));
      expect(
        container.padding,
        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      );
    });

    testWidgets('icon uses onErrorContainer color', (tester) async {
      await tester.pumpWidget(buildSubject());

      final context = tester.element(find.byType(OfflineBanner));
      final expectedColor = Theme.of(context).colorScheme.onErrorContainer;
      final icon = tester.widget<Icon>(find.byIcon(Icons.cloud_off));

      expect(icon.color, expectedColor);
    });
  });
}
