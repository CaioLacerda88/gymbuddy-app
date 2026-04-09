// ignore_for_file: invalid_annotation_target
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'exercise.freezed.dart';
part 'exercise.g.dart';

enum MuscleGroup {
  chest,
  back,
  legs,
  shoulders,
  arms,
  core,
  cardio;

  String get displayName => name[0].toUpperCase() + name.substring(1);

  IconData get icon => switch (this) {
    chest => Icons.fitness_center,
    back => Icons.accessibility_new,
    legs => Icons.directions_walk,
    shoulders => Icons.expand,
    arms => Icons.sports_martial_arts,
    core => Icons.circle_outlined,
    cardio => Icons.directions_run,
  };

  static MuscleGroup fromString(String value) =>
      values.firstWhere((e) => e.name == value);
}

enum EquipmentType {
  barbell,
  dumbbell,
  cable,
  machine,
  bodyweight,
  bands,
  kettlebell;

  String get displayName => name[0].toUpperCase() + name.substring(1);

  IconData get icon => switch (this) {
    barbell => Icons.fitness_center,
    dumbbell => Icons.fitness_center,
    cable => Icons.cable,
    machine => Icons.precision_manufacturing,
    bodyweight => Icons.self_improvement,
    bands => Icons.straighten,
    kettlebell => Icons.sports_gymnastics,
  };

  static EquipmentType fromString(String value) =>
      values.firstWhere((e) => e.name == value);
}

@freezed
class Exercise with _$Exercise {
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
