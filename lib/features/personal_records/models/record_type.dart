enum RecordType {
  maxWeight,
  maxReps,
  maxVolume;

  String get displayName => switch (this) {
    maxWeight => 'Max Weight',
    maxReps => 'Max Reps',
    maxVolume => 'Max Volume',
  };

  String get toSnakeCase => switch (this) {
    maxWeight => 'max_weight',
    maxReps => 'max_reps',
    maxVolume => 'max_volume',
  };

  static RecordType fromString(String value) => switch (value) {
    'max_weight' => maxWeight,
    'max_reps' => maxReps,
    'max_volume' => maxVolume,
    _ => throw ArgumentError('Unknown RecordType: $value'),
  };
}
