enum WeightUnit {
  kg,
  lbs;

  String get displayName => name.toUpperCase();

  double get defaultIncrement => switch (this) {
    kg => 2.5,
    lbs => 5.0,
  };

  static WeightUnit fromString(String value) =>
      values.firstWhere((e) => e.name == value);
}
