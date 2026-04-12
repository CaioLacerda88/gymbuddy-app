// ignore_for_file: invalid_annotation_target
import 'package:freezed_annotation/freezed_annotation.dart';

import 'record_type.dart';

part 'personal_record.freezed.dart';
part 'personal_record.g.dart';

RecordType _recordTypeFromJson(dynamic value) =>
    RecordType.fromString(value as String? ?? 'max_weight');

String _recordTypeToJson(RecordType type) => type.toSnakeCase;

@freezed
abstract class PersonalRecord with _$PersonalRecord {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory PersonalRecord({
    required String id,
    required String userId,
    required String exerciseId,
    @JsonKey(
      defaultValue: RecordType.maxWeight,
      fromJson: _recordTypeFromJson,
      toJson: _recordTypeToJson,
    )
    required RecordType recordType,
    required double value,
    required DateTime achievedAt,
    String? setId,
    int? reps,
  }) = _PersonalRecord;

  factory PersonalRecord.fromJson(Map<String, dynamic> json) =>
      _$PersonalRecordFromJson(json);
}
