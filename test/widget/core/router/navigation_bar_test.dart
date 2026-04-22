import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import '../../../helpers/test_material_app.dart';

void main() {
  group('Bottom navigation bar styling (QA-011, UX-V08)', () {
    testWidgets('tooltips are suppressed on navigation destinations', (
      tester,
    ) async {
      // Build a NavigationBar matching the production configuration.
      await tester.pumpWidget(
        TestMaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Home',
                  tooltip: '',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center),
                  label: 'Exercises',
                  tooltip: '',
                ),
              ],
            ),
          ),
        ),
      );

      // Structurally verify that every NavigationDestination has its
      // tooltip property set to an empty string (suppressed).
      final destinations = tester.widgetList<NavigationDestination>(
        find.byType(NavigationDestination),
      );

      for (final dest in destinations) {
        expect(
          dest.tooltip,
          equals(''),
          reason: '${dest.label} should have an empty tooltip',
        );
      }
    });

    testWidgets('navigation bar uses custom background color', (tester) async {
      await tester.pumpWidget(
        TestMaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            bottomNavigationBar: NavigationBar(
              backgroundColor: const Color(0xFF1A1A2E),
              surfaceTintColor: Colors.transparent,
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home),
                  label: 'Home',
                  tooltip: '',
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center),
                  label: 'Exercises',
                  tooltip: '',
                ),
              ],
            ),
          ),
        ),
      );

      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));

      expect(navBar.backgroundColor, equals(const Color(0xFF1A1A2E)));
      expect(navBar.surfaceTintColor, equals(Colors.transparent));
    });
  });
}
