/// Smoke-tests every [AppEquipmentIcons] constant. Mirrors the muscle-icon
/// contract but also asserts the enum-to-glyph wiring for [EquipmentType]:
/// in particular, [EquipmentType.barbell] MUST reuse [AppIcons.lift] rather
/// than ship a duplicate barbell glyph — the lift icon is the app's signature
/// constant and doubles as the barbell equipment affordance.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/core/theme/app_equipment_icons.dart';
import 'package:repsaga/core/theme/app_icons.dart';
import 'package:repsaga/core/theme/app_theme.dart';
import 'package:repsaga/features/exercises/models/exercise.dart';

void main() {
  final icons = <String, String>{
    'dumbbell': AppEquipmentIcons.dumbbell,
    'cable': AppEquipmentIcons.cable,
    'machine': AppEquipmentIcons.machine,
    'bodyweight': AppEquipmentIcons.bodyweight,
    'bands': AppEquipmentIcons.bands,
    'kettlebell': AppEquipmentIcons.kettlebell,
  };

  group('AppEquipmentIcons constants — v3-silhouette asset paths', () {
    for (final entry in icons.entries) {
      test(
        '${entry.key} is an asset path under assets/icons/v3-silhouette/',
        () {
          final path = entry.value;
          expect(path, isNotEmpty);
          expect(path, startsWith('assets/icons/v3-silhouette/'));
          expect(path, endsWith('.svg'));
        },
      );
    }
  });

  group('AppEquipmentIcons — AppIcons.render size + color propagation', () {
    for (final entry in icons.entries) {
      for (final size in const [24.0, 48.0, 64.0]) {
        testWidgets('${entry.key} renders at ${size.toInt()} dp with explicit '
            'color', (tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Center(
                  child: AppIcons.render(
                    entry.value,
                    color: AppColors.hotViolet,
                    size: size,
                  ),
                ),
              ),
            ),
          );

          final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
          expect(picture.width, size);
          expect(picture.height, size);
          expect(
            picture.colorFilter,
            const ColorFilter.mode(AppColors.hotViolet, BlendMode.srcIn),
          );
        });
      }

      testWidgets('${entry.key} inherits color from ancestor IconTheme '
          'when color: is omitted', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: IconTheme.merge(
                data: const IconThemeData(color: AppColors.hotViolet),
                child: Center(child: AppIcons.render(entry.value, size: 24)),
              ),
            ),
          ),
        );

        final picture = tester.widget<SvgPicture>(find.byType(SvgPicture));
        expect(
          picture.colorFilter,
          const ColorFilter.mode(AppColors.hotViolet, BlendMode.srcIn),
        );
      });
    }
  });

  group('EquipmentType.svgIcon — enum-to-glyph wiring', () {
    test('barbell reuses AppIcons.lift (no duplicate glyph)', () {
      expect(EquipmentType.barbell.svgIcon, AppIcons.lift);
    });

    test('every other equipment type points at an AppEquipmentIcons glyph', () {
      expect(EquipmentType.dumbbell.svgIcon, AppEquipmentIcons.dumbbell);
      expect(EquipmentType.cable.svgIcon, AppEquipmentIcons.cable);
      expect(EquipmentType.machine.svgIcon, AppEquipmentIcons.machine);
      expect(EquipmentType.bodyweight.svgIcon, AppEquipmentIcons.bodyweight);
      expect(EquipmentType.bands.svgIcon, AppEquipmentIcons.bands);
      expect(EquipmentType.kettlebell.svgIcon, AppEquipmentIcons.kettlebell);
    });

    test('every enum value points at a v3-silhouette asset path', () {
      for (final type in EquipmentType.values) {
        expect(type.svgIcon, isNotEmpty);
        expect(type.svgIcon, startsWith('assets/icons/v3-silhouette/'));
        expect(type.svgIcon, endsWith('.svg'));
      }
    });
  });

  group('MuscleGroup.svgIcon — enum-to-glyph wiring', () {
    test('every muscle group points at a v3-silhouette asset path', () {
      for (final group in MuscleGroup.values) {
        expect(group.svgIcon, isNotEmpty);
        expect(group.svgIcon, startsWith('assets/icons/v3-silhouette/'));
        expect(group.svgIcon, endsWith('.svg'));
      }
    });
  });
}
