// ignore_for_file: invalid_annotation_target
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

  /// Pixel-art icon asset path. Every enum value maps 1:1 to a registered
  /// PNG in `assets/pixel/muscle/`; see `pubspec.yaml`.
  String get iconPath => 'assets/pixel/muscle/$name.png';

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

  /// Pixel-art icon asset path. Every enum value maps 1:1 to a registered
  /// PNG in `assets/pixel/equipment/`; see `pubspec.yaml`.
  String get iconPath => 'assets/pixel/equipment/$name.png';

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
