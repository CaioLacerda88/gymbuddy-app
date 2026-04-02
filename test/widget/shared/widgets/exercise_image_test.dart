import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/shared/widgets/exercise_image.dart';

Widget _buildTestWidget(ExerciseImage image) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(body: Center(child: image)),
  );
}

void main() {
  group('ExerciseImage', () {
    group('when imageUrl is null', () {
      testWidgets('renders fallback icon', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            const ExerciseImage(
              imageUrl: null,
              fallbackIcon: Icons.fitness_center,
              width: 100,
              height: 100,
            ),
          ),
        );

        expect(find.byIcon(Icons.fitness_center), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsNothing);
      });
    });

    group('when imageUrl is empty string', () {
      testWidgets('renders fallback icon', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            const ExerciseImage(
              imageUrl: '',
              fallbackIcon: Icons.fitness_center,
              width: 100,
              height: 100,
            ),
          ),
        );

        expect(find.byIcon(Icons.fitness_center), findsOneWidget);
        expect(find.byType(CachedNetworkImage), findsNothing);
      });
    });

    group('when imageUrl is provided', () {
      testWidgets('renders CachedNetworkImage', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            const ExerciseImage(
              imageUrl: 'https://example.com/test.jpg',
              fallbackIcon: Icons.fitness_center,
              width: 100,
              height: 100,
            ),
          ),
        );

        expect(find.byType(CachedNetworkImage), findsOneWidget);
      });

      testWidgets('wraps image in ClipRRect with borderRadius', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            ExerciseImage(
              imageUrl: 'https://example.com/test.jpg',
              fallbackIcon: Icons.fitness_center,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(clipRRect.borderRadius, BorderRadius.circular(12));
      });
    });

    group('fallback icon sizing', () {
      testWidgets('icon size is 40% of height', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            const ExerciseImage(
              imageUrl: null,
              fallbackIcon: Icons.fitness_center,
              height: 100,
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.fitness_center));
        expect(icon.size, 40.0); // 100 * 0.4
      });

      testWidgets('icon size defaults to 48 * 0.4 when height is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            const ExerciseImage(
              imageUrl: null,
              fallbackIcon: Icons.fitness_center,
            ),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.fitness_center));
        expect(icon.size, closeTo(19.2, 0.001)); // 48 * 0.4
      });
    });

    group('borderRadius on fallback', () {
      testWidgets('applies borderRadius to fallback Container decoration', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            ExerciseImage(
              imageUrl: null,
              fallbackIcon: Icons.fitness_center,
              width: 100,
              height: 100,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );

        final container = tester.widget<Container>(
          find.ancestor(
            of: find.byIcon(Icons.fitness_center),
            matching: find.byType(Container),
          ),
        );
        final decoration = container.decoration as BoxDecoration;
        expect(decoration.borderRadius, BorderRadius.circular(16));
      });
    });
  });
}
