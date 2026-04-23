import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/shared/widgets/pixel_image.dart';

void main() {
  group('PixelImage', () {
    testWidgets(
      'forwards FilterQuality.none to the underlying Image (nearest-neighbor)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: PixelImage(
              'assets/pixel/branding/repsaga_wordmark.png',
              semanticLabel: 'RepSaga wordmark',
            ),
          ),
        );

        final image = tester.widget<Image>(find.byType(Image));
        // If this ever flips to bilinear the entire pixel-art direction
        // collapses into blurred dark gradients at runtime. Hard-lock it.
        expect(image.filterQuality, FilterQuality.none);
        expect(image.fit, BoxFit.contain);
      },
    );

    testWidgets('forwards semanticLabel to the underlying Image', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PixelImage(
            'assets/pixel/branding/repsaga_wordmark.png',
            semanticLabel: 'RepSaga wordmark',
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.semanticLabel, 'RepSaga wordmark');
    });

    testWidgets(
      'treats an empty semanticLabel as "exclude from semantics" (decorative)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: PixelImage('assets/pixel/micro/check.png', semanticLabel: ''),
          ),
        );

        final image = tester.widget<Image>(find.byType(Image));
        expect(image.semanticLabel, isNull);
        expect(image.excludeFromSemantics, isTrue);
      },
    );

    testWidgets('forwards width, height, and color tint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(
            child: PixelImage(
              'assets/pixel/micro/check.png',
              semanticLabel: 'check',
              width: 24,
              height: 24,
              color: Color(0xFF00FF00),
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 24);
      expect(image.height, 24);
      expect(image.color, const Color(0xFF00FF00));
    });

    testWidgets(
      'leaves width and height null when not provided (aspect-ratio preservation)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: PixelImage(
              'assets/pixel/branding/repsaga_wordmark.png',
              semanticLabel: 'logo',
            ),
          ),
        );

        final image = tester.widget<Image>(find.byType(Image));
        expect(image.width, isNull);
        expect(image.height, isNull);
      },
    );
  });
}
