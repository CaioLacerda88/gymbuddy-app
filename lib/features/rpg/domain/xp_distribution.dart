import '../models/body_part.dart';

/// Applies an `xp_attribution` map to a single set's total XP.
///
/// The attribution map (spec §5) lives on `exercises.xp_attribution` JSONB
/// — keys are `body_part.dbValue`, values are 0..1 floats summing to 1.00 ±
/// 0.01. The DB-side IMMUTABLE helper `xp_attribution_sum(jsonb)` enforces
/// this; the repository layer is responsible for parsing the JSONB into
/// the [Attribution] model below before reaching this calculator.
///
/// **NULL fallback rule:** when an exercise has no attribution map (e.g.
/// user-created exercises pre-Stage 6 of the localization rollout), the
/// caller should pass `Attribution.fromPrimaryMuscle(muscleGroup)` — 1.0 to
/// the primary muscle group, nothing else. This keeps the math
/// deterministic without requiring every user-created exercise to carry
/// the JSONB column on day 1.
class XpDistribution {
  const XpDistribution._();

  /// Distributes [setXp] across body parts according to [attribution].
  ///
  /// Output map only contains body parts that received non-zero XP; this
  /// matches the SQL `record_set_xp` RPC, which only INSERTs rows for
  /// body parts present in the attribution map.
  static Map<BodyPart, double> distribute({
    required double setXp,
    required Attribution attribution,
  }) {
    if (setXp <= 0 || attribution.shares.isEmpty) {
      return const <BodyPart, double>{};
    }
    final out = <BodyPart, double>{};
    attribution.shares.forEach((bp, share) {
      if (share <= 0) return;
      out[bp] = setXp * share;
    });
    return out;
  }
}

/// Validated attribution map. Constructors ensure non-negative shares and a
/// sum within the spec tolerance (1.00 ± 0.01).
///
/// Plain value class — not Freezed. The map shape (`Map<BodyPart, double>`)
/// makes a const literal in Freezed awkward and the type isn't part of any
/// JSON wire serialization (the wire format is JSONB, parsed in the
/// repository layer).
class Attribution {
  Attribution._(this.shares);

  /// Build from a parsed JSONB map (string → num). Throws [ArgumentError]
  /// if any key is unknown, any value is negative, or the sum drifts
  /// beyond [sumTolerance].
  ///
  /// Keys outside [BodyPart] tokens are rejected — silently dropping them
  /// would mask a data bug. If a future cardio key (`cardio`) appears in
  /// v1 data it is accepted; the cardio share simply earns nothing in the
  /// v1 character-level path because cardio is not in [activeBodyParts].
  factory Attribution.fromMap(Map<String, num> map) {
    if (map.isEmpty) {
      throw ArgumentError.value(map, 'attribution', 'must not be empty');
    }
    final shares = <BodyPart, double>{};
    var sum = 0.0;
    map.forEach((key, value) {
      final bp = BodyPart.tryFromDbValue(key);
      if (bp == null) {
        throw ArgumentError.value(key, 'attribution.key', 'unknown body part');
      }
      final v = value.toDouble();
      if (v < 0 || v.isNaN || v.isInfinite) {
        throw ArgumentError.value(
          value,
          'attribution.value',
          'must be a finite non-negative number',
        );
      }
      shares[bp] = v;
      sum += v;
    });
    // Float arithmetic can leave (sum - 1.0).abs() at e.g. 0.0100000000001
    // even when the inputs were 0.59 + 0.40. We add a small ULP cushion to
    // the tolerance so cleanly-typed shares aren't rejected for noise.
    const sumToleranceWithCushion = sumTolerance + 1e-9;
    if ((sum - 1.0).abs() > sumToleranceWithCushion) {
      throw ArgumentError.value(
        map,
        'attribution',
        'sum ${sum.toStringAsFixed(4)} drifts beyond ±$sumTolerance from 1.0',
      );
    }
    return Attribution._(Map.unmodifiable(shares));
  }

  /// NULL-fallback constructor. Used when an exercise has no
  /// `xp_attribution` JSONB — the entire set's XP goes to its primary
  /// muscle group at share 1.0.
  ///
  /// `cardio` is accepted for forward compatibility but earns nothing in
  /// the v1 character-level path.
  factory Attribution.fromPrimaryMuscle(BodyPart primary) {
    return Attribution._(Map.unmodifiable({primary: 1.0}));
  }

  /// Body-part → 0..1 share. Sums to 1.0 ± 0.01.
  final Map<BodyPart, double> shares;

  /// Spec tolerance — `xp_attribution_sums_to_one` CHECK constraint.
  static const double sumTolerance = 0.01;

  /// Sum of all shares — used by tests and the SQL helper-function CHECK.
  double get sum {
    var s = 0.0;
    for (final v in shares.values) {
      s += v;
    }
    return s;
  }

  /// JSONB-style map for serialization. Keys are `BodyPart.dbValue`.
  Map<String, double> toJson() {
    return shares.map((bp, share) => MapEntry(bp.dbValue, share));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Attribution) return false;
    if (shares.length != other.shares.length) return false;
    for (final entry in shares.entries) {
      if (other.shares[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    // Order-independent hash: sort entries by body-part dbValue so two
    // Attribution maps with the same shares hash equal regardless of the
    // order they were inserted in.
    final entries = shares.entries.toList()
      ..sort((a, b) => a.key.dbValue.compareTo(b.key.dbValue));
    return Object.hashAll(entries.expand((e) => [e.key, e.value]));
  }

  @override
  String toString() => 'Attribution($shares)';
}
