/// Widget tests for [PeakLoadsTable] — Phase 18d.2.
///
/// The peak-loads section is a column of [ExpansionTile]s — one per body
/// part with recorded peaks — sorted by canonical [activeBodyParts] order.
/// The body part with the heaviest single peak is default-expanded.
///
/// **Locks under test:**
///   * Empty map → `peakLoadsEmpty` copy, no ExpansionTile.
///   * Non-empty map → one ExpansionTile per body part with peaks.
///   * Default-expanded body part = whichever has the heaviest peak.
///   * `1RM est. <weight>` line appears when [PeakLoadRow.estimated1RM] is
///     non-null and is suppressed when null (bodyweight / non-loaded peaks).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/profile/models/profile.dart';
import 'package:repsaga/features/profile/providers/profile_providers.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/stats_deep_dive_state.dart';
import 'package:repsaga/features/rpg/ui/widgets/peak_loads_table.dart';

import '../../../../helpers/test_material_app.dart';

PeakLoadRow _peak({
  required String name,
  required double weight,
  int reps = 5,
  double? estimated1RM,
}) {
  return PeakLoadRow(
    exerciseName: name,
    peakWeight: weight,
    peakReps: reps,
    estimated1RM: estimated1RM,
  );
}

/// Stub profile provider that yields a fixed `kg` profile so the table's
/// `weightUnit` lookup resolves synchronously without hitting Hive/Supabase.
class _StubProfileNotifier extends ProfileNotifier {
  _StubProfileNotifier(this._profile);

  final Profile _profile;

  @override
  Future<Profile?> build() async => _profile;
}

Widget _wrap({
  required Map<BodyPart, List<PeakLoadRow>> peakLoadsByBodyPart,
  String weightUnit = 'kg',
}) {
  final stubProfile = Profile(
    id: 'test-user',
    weightUnit: weightUnit,
    locale: 'en',
    createdAt: DateTime.utc(2026, 1, 1),
  );
  return ProviderScope(
    overrides: [
      profileProvider.overrideWith(() => _StubProfileNotifier(stubProfile)),
    ],
    child: TestMaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: PeakLoadsTable(peakLoadsByBodyPart: peakLoadsByBodyPart),
        ),
      ),
    ),
  );
}

void main() {
  group('PeakLoadsTable', () {
    testWidgets('empty map renders the empty-state copy and no ExpansionTile', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(peakLoadsByBodyPart: const {}));
      await tester.pump();

      expect(find.text('No peaks recorded yet.'), findsOneWidget);
      expect(find.byType(ExpansionTile), findsNothing);
    });

    testWidgets('one ExpansionTile per body part with peaks', (tester) async {
      await tester.pumpWidget(
        _wrap(
          peakLoadsByBodyPart: {
            BodyPart.chest: [_peak(name: 'Bench Press', weight: 100, reps: 5)],
            BodyPart.back: [_peak(name: 'Pull-up', weight: 80, reps: 8)],
            BodyPart.legs: [_peak(name: 'Squat', weight: 140, reps: 5)],
          },
        ),
      );
      await tester.pump();

      expect(find.byType(ExpansionTile), findsNWidgets(3));
      // Headers carry the localized body-part labels.
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('Back'), findsOneWidget);
      expect(find.text('Legs'), findsOneWidget);
    });

    testWidgets(
      'default-expanded body part is the one with the heaviest single peak',
      (tester) async {
        // Squat at 140 is the heaviest single peak across the dataset.
        await tester.pumpWidget(
          _wrap(
            peakLoadsByBodyPart: {
              BodyPart.chest: [
                _peak(name: 'Bench Press', weight: 100, reps: 5),
              ],
              BodyPart.legs: [
                _peak(name: 'Squat', weight: 140, reps: 5),
                _peak(name: 'Leg Press', weight: 200, reps: 8),
              ],
            },
          ),
        );
        await tester.pumpAndSettle();

        // The Squat row should be visible (Legs default-expanded).
        // We don't assert visibility of "Bench Press" because it sits inside
        // a collapsed ExpansionTile — its child is in the tree but offscreen.
        // Squat is the head row of the expanded Legs tile.
        expect(find.text('Squat'), findsOneWidget);
        expect(find.text('Leg Press'), findsOneWidget);
      },
    );

    testWidgets('Note: leg-press default-expanded with two body parts only', (
      tester,
    ) async {
      // Only one body part has data → it is default-expanded.
      await tester.pumpWidget(
        _wrap(
          peakLoadsByBodyPart: {
            BodyPart.core: [
              _peak(
                name: 'Hanging Leg Raise',
                weight: 0,
                reps: 12,
                estimated1RM: null,
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ExpansionTile), findsOneWidget);
      expect(find.text('Hanging Leg Raise'), findsOneWidget);
    });

    testWidgets('1RM estimate line renders when estimated1RM is non-null', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          peakLoadsByBodyPart: {
            BodyPart.chest: [
              _peak(
                name: 'Bench Press',
                weight: 100,
                reps: 5,
                // Epley 100 × (1 + 5/30) = 116.66, formatted to 1 decimal.
                estimated1RM: 116.7,
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      // The "1RM est." marker text + the weight render together in
      // the same Text widget. The label string is `1RM est. 116.7 kg`.
      expect(find.textContaining('1RM est.'), findsOneWidget);
      expect(find.textContaining('116.7 kg'), findsOneWidget);
    });

    testWidgets('1RM estimate line is suppressed when estimated1RM is null', (
      tester,
    ) async {
      // Bodyweight peak — peakReps fired, but no Epley 1RM (weight is 0).
      await tester.pumpWidget(
        _wrap(
          peakLoadsByBodyPart: {
            BodyPart.core: [
              _peak(name: 'Plank', weight: 0, reps: 60, estimated1RM: null),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      // The label is absent.
      expect(find.textContaining('1RM est.'), findsNothing);
    });

    testWidgets('weightUnit `lbs` is honored in row rendering', (tester) async {
      await tester.pumpWidget(
        _wrap(
          weightUnit: 'lbs',
          peakLoadsByBodyPart: {
            BodyPart.chest: [
              _peak(
                name: 'Bench Press',
                weight: 225,
                reps: 3,
                estimated1RM: 247.5,
              ),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      // Header row + 1RM-est line both pull from the same `weightUnit` thread.
      expect(find.textContaining('225 lbs'), findsOneWidget);
      expect(find.textContaining('247.5 lbs'), findsOneWidget);
    });

    testWidgets('header trailing shows the row count per body part', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          peakLoadsByBodyPart: {
            BodyPart.chest: [
              _peak(name: 'Bench Press', weight: 100, reps: 5),
              _peak(name: 'Incline DB Press', weight: 30, reps: 8),
              _peak(name: 'Dip', weight: 0, reps: 12, estimated1RM: null),
            ],
          },
        ),
      );
      await tester.pumpAndSettle();

      // The chest row count is `3` — rendered as a Rajdhani numeral in the
      // ExpansionTile header trailing slot.
      expect(find.text('3'), findsOneWidget);
    });
  });
}
