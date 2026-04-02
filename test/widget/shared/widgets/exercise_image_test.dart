import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymbuddy_app/core/theme/app_theme.dart';
import 'package:gymbuddy_app/shared/widgets/exercise_image.dart';

/// Fake HTTP overrides that return a transparent 1x1 PNG for any image request.
/// This prevents CachedNetworkImage from making real HTTP calls in tests.
class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

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
        // Should NOT render CachedNetworkImage
        expect(find.byType(CachedNetworkImage), findsNothing);
      });

      testWidgets('renders Container with decoration', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            const ExerciseImage(
              imageUrl: null,
              fallbackIcon: Icons.fitness_center,
              width: 120,
              height: 80,
            ),
          ),
        );

        // The fallback Container should be sized correctly
        final container = tester.widget<Container>(
          find.ancestor(
            of: find.byIcon(Icons.fitness_center),
            matching: find.byType(Container),
          ),
        );
        expect(container.constraints?.maxWidth, 120);
        expect(container.constraints?.maxHeight, 80);
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
      late HttpOverrides? originalOverrides;

      setUp(() {
        originalOverrides = HttpOverrides.current;
        HttpOverrides.global = _FakeHttpOverrides();
      });

      tearDown(() {
        HttpOverrides.global = originalOverrides;
      });

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

      testWidgets('passes correct BoxFit (default contain)', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            const ExerciseImage(
              imageUrl: 'https://example.com/test.jpg',
              fallbackIcon: Icons.fitness_center,
            ),
          ),
        );

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.fit, BoxFit.contain);
      });

      testWidgets('passes custom BoxFit when specified', (tester) async {
        await tester.pumpWidget(
          _buildTestWidget(
            const ExerciseImage(
              imageUrl: 'https://example.com/test.jpg',
              fallbackIcon: Icons.fitness_center,
              fit: BoxFit.cover,
            ),
          ),
        );

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.fit, BoxFit.cover);
      });

      testWidgets('wraps image in ClipRRect with borderRadius', (
        tester,
      ) async {
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

      testWidgets('passes width and height to CachedNetworkImage', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildTestWidget(
            const ExerciseImage(
              imageUrl: 'https://example.com/test.jpg',
              fallbackIcon: Icons.fitness_center,
              width: 200,
              height: 150,
            ),
          ),
        );

        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage),
        );
        expect(cachedImage.width, 200);
        expect(cachedImage.height, 150);
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
