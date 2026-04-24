// ignore_for_file: invalid_annotation_target
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

/// High-level muscle group an exercise trains. Used both for filtering in the
/// browse list and as a chip label on detail/active sheets.
enum MuscleGroup {
  chest,
  back,
  legs,
  shoulders,
  arms,
  core,
  cardio;

  String get displayName => name[0].toUpperCase() + name.substring(1);

  /// Material icon surfaced alongside the muscle-group label across the app
  /// (filter chips, exercise detail sheet, active-workout preview sheet).
  ///
  /// These are structural enum metadata — a new muscle group ships with its
  /// icon in the same commit as the enum value, so the pairing is enforced
  /// at compile time.
  IconData get icon => switch (this) {
    MuscleGroup.chest => Icons.accessibility_new_rounded,
    MuscleGroup.back => Icons.airline_seat_flat_rounded,
    MuscleGroup.legs => Icons.directions_run_rounded,
    MuscleGroup.shoulders => Icons.unfold_more_rounded,
    MuscleGroup.arms => Icons.sports_martial_arts_rounded,
    MuscleGroup.core => Icons.center_focus_strong_rounded,
    MuscleGroup.cardio => Icons.favorite_rounded,
  };

  static MuscleGroup fromString(String value) =>
      values.firstWhere((e) => e.name == value);
}

/// Equipment an exercise uses. Same UX surfaces as [MuscleGroup].
enum EquipmentType {
  barbell,
  dumbbell,
  cable,
  machine,
  bodyweight,
  bands,
  kettlebell;

  String get displayName => name[0].toUpperCase() + name.substring(1);

  /// Material icon surfaced alongside the equipment-type label across the app.
  /// See [MuscleGroup.icon] for the same rationale.
  IconData get icon => switch (this) {
    EquipmentType.barbell => Icons.fitness_center_rounded,
    EquipmentType.dumbbell => Icons.sports_gymnastics_rounded,
    EquipmentType.cable => Icons.cable_rounded,
    EquipmentType.machine => Icons.precision_manufacturing_rounded,
    EquipmentType.bodyweight => Icons.self_improvement_rounded,
    EquipmentType.bands => Icons.linear_scale_rounded,
    EquipmentType.kettlebell => Icons.sports_rounded,
  };

  static EquipmentType fromString(String value) =>
      values.firstWhere((e) => e.name == value);
}

@freezed
abstract class Exercise with _$Exercise {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Exercise({
    required String id,
    required String name,
    required MuscleGroup muscleGroup,
    required EquipmentType equipmentType,
    @JsonKey(defaultValue: false) required bool isDefault,
    String? description,
    String? formTips,
    String? imageStartUrl,
    String? imageEndUrl,
    String? userId,
    DateTime? deletedAt,
    required DateTime createdAt,
  }) = _Exercise;

  factory Exercise.fromJson(Map<String, dynamic> json) =>
      _$ExerciseFromJson(json);
}
