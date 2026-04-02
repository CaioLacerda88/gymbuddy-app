enum SetType {
  working,
  warmup,
  dropset,
  failure;

  String get displayName => switch (this) {
    working => 'Working',
    warmup => 'Warm-up',
    dropset => 'Drop Set',
    failure => 'To Failure',
  };

  static SetType fromString(String value) =>
      values.firstWhere((e) => e.name == value);
}
