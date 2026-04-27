import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repsaga/features/rpg/data/rpg_repository.dart';
import 'package:repsaga/features/rpg/models/body_part.dart';
import 'package:repsaga/features/rpg/models/body_part_progress.dart';
import 'package:repsaga/features/rpg/models/character_sheet_state.dart';
import 'package:repsaga/features/rpg/models/vitality_state.dart';
import 'package:repsaga/features/rpg/providers/active_title_provider.dart';
import 'package:repsaga/features/rpg/providers/character_sheet_provider.dart';
import 'package:repsaga/features/rpg/providers/class_provider.dart';
import 'package:repsaga/features/rpg/providers/rpg_progress_provider.dart';

class _FakeRpgProgressNotifier extends RpgProgressNotifier {
  _FakeRpgProgressNotifier(this._snapshot);
  final RpgProgressSnapshot _snapshot;

  @override
  Future<RpgProgressSnapshot> build() async => _snapshot;
}

BodyPartProgress _row({
  required BodyPart bodyPart,
  required int rank,
  required double totalXp,
  double vitalityEwma = 0,
  double vitalityPeak = 0,
}) {
  return BodyPartProgress(
    userId: 'u1',
    bodyPart: bodyPart,
    totalXp: totalXp,
    rank: rank,
    vitalityEwma: vitalityEwma,
    vitalityPeak: vitalityPeak,
    lastEventAt: null,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

ProviderContainer _container({
  required RpgProgressSnapshot snapshot,
  String? activeTitle,
  String? className,
}) {
  return ProviderContainer(
    overrides: [
      rpgProgressProvider.overrideWith(
        () => _FakeRpgProgressNotifier(snapshot),
      ),
      activeTitleProvider.overrideWithValue(activeTitle),
      characterClassProvider.overrideWithValue(className),
    ],
  );
}

Future<CharacterSheetState> _read(ProviderContainer c) async {
  // Wait for the upstream AsyncNotifier to resolve.
  await c.read(rpgProgressProvider.future);
  return c.read(characterSheetProvider).requireValue;
}

void main() {
  group('characterSheetProvider — composition', () {
    test('day-0 user: six dormant entries, isZeroHistory=true', () async {
      final c = _container(snapshot: RpgProgressSnapshot.empty);
      addTearDown(c.dispose);

      final sheet = await _read(c);

      expect(sheet.bodyPartProgress.length, 6);
      expect(sheet.lifetimeXp, 0);
      expect(sheet.isZeroHistory, true);
      for (final e in sheet.bodyPartProgress) {
        expect(e.rank, 1);
        expect(e.vitalityState, VitalityState.dormant);
        expect(e.isUntrained, true);
      }
      expect(sheet.haloState, VitalityState.dormant);
    });

    test(
      'preserves activeBodyParts canonical order regardless of map order',
      () async {
        final snapshot = RpgProgressSnapshot(
          byBodyPart: {
            // Insert in a deliberately scrambled order.
            BodyPart.core: _row(bodyPart: BodyPart.core, rank: 5, totalXp: 100),
            BodyPart.chest: _row(
              bodyPart: BodyPart.chest,
              rank: 3,
              totalXp: 80,
            ),
          },
          characterState: const CharacterState(
            userId: 'u1',
            characterLevel: 2,
            maxRank: 5,
            minRank: 1,
            lifetimeXp: 180,
          ),
        );
        final c = _container(snapshot: snapshot);
        addTearDown(c.dispose);

        final sheet = await _read(c);
        expect(
          sheet.bodyPartProgress.map((e) => e.bodyPart).toList(),
          activeBodyParts,
        );
      },
    );

    test(
      'rank curve slice: xpInRank + xpForNextRank computed from totalXp',
      () async {
        // At rank 5, cumulative threshold is 60 * (1.10^4 - 1) / 0.10 ≈ 278.46.
        // Set totalXp slightly above so xpInRank > 0 and xpForNextRank > 0.
        final snapshot = RpgProgressSnapshot(
          byBodyPart: {
            BodyPart.chest: _row(
              bodyPart: BodyPart.chest,
              rank: 5,
              totalXp: 300,
              vitalityEwma: 50,
              vitalityPeak: 60,
            ),
          },
          characterState: const CharacterState(
            userId: 'u1',
            characterLevel: 1,
            maxRank: 5,
            minRank: 1,
            lifetimeXp: 300,
          ),
        );
        final c = _container(snapshot: snapshot);
        addTearDown(c.dispose);

        final sheet = await _read(c);
        final chest = sheet.bodyPartProgress.firstWhere(
          (e) => e.bodyPart == BodyPart.chest,
        );

        expect(chest.rank, 5);
        expect(chest.xpInRank, greaterThan(0));
        expect(chest.xpForNextRank, greaterThan(0));
        expect(chest.vitalityState, VitalityState.active);
      },
    );

    test('class + active title pass through from stub providers', () async {
      final c = _container(
        snapshot: RpgProgressSnapshot.empty,
        activeTitle: 'Iron-Chested',
        className: 'Bulwark',
      );
      addTearDown(c.dispose);

      final sheet = await _read(c);
      expect(sheet.activeTitle, 'Iron-Chested');
      expect(sheet.className, 'Bulwark');
    });

    test(
      'halo state collapses to mean Vitality across active body parts',
      () async {
        // Two body parts active at 80% (Radiant range), four untouched.
        // Mean = 80, peak > 0 → Radiant.
        final snapshot = RpgProgressSnapshot(
          byBodyPart: {
            BodyPart.chest: _row(
              bodyPart: BodyPart.chest,
              rank: 10,
              totalXp: 1000,
              vitalityEwma: 80,
              vitalityPeak: 90,
            ),
            BodyPart.back: _row(
              bodyPart: BodyPart.back,
              rank: 8,
              totalXp: 700,
              vitalityEwma: 80,
              vitalityPeak: 85,
            ),
          },
          characterState: const CharacterState(
            userId: 'u1',
            characterLevel: 4,
            maxRank: 10,
            minRank: 1,
            lifetimeXp: 1700,
          ),
        );
        final c = _container(snapshot: snapshot);
        addTearDown(c.dispose);

        final sheet = await _read(c);
        expect(sheet.haloState, VitalityState.radiant);
      },
    );
  });
}
