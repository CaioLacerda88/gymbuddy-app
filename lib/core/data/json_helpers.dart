/// JSON-row helpers for the repository layer.
///
/// **Why:** Supabase rows arrive as `Map<String, dynamic>`. Hard `as T` casts
/// produce cryptic Dart errors
/// (`type 'Null' is not a subtype of type 'String' in type cast`) when a
/// column shape drifts (RLS hides a row, a migration renames a field, an RPC
/// returns the wrong projection). The user sees the raw cast string in the
/// pending-sync sheet — not actionable, leaks schema names, and erases the
/// chance to capture context to Sentry.
///
/// These helpers replace `as T` at every untrusted external boundary with a
/// typed [DatabaseException] carrying the field name, the expected type, and
/// the actual type — so the failure mode is "DatabaseException: Field 'id' has
/// wrong type: expected String, got Null" instead of an opaque Dart cast.
///
/// **Scope:** Use these for repository-layer JSON deserialization where the
/// caller cannot prove the shape statically (anything coming back from
/// `from(...).select(...)` or `rpc(...)`). Do **not** use them for in-process
/// typed objects (e.g. `state.extra` in router builders) — that's a
/// programmer-error class, not a database-error class; throw [StateError] or
/// [ArgumentError] there instead.
library;

import '../exceptions/app_exception.dart';

/// Reads a required field from a JSON row, throwing [DatabaseException] if
/// the field is missing or has the wrong type.
///
/// Centralizes the audit pattern from BUG-010: every untrusted boundary cast
/// becomes a typed exception with enough context to debug the schema drift.
T requireField<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw DatabaseException(
      "Missing required field '$key' in JSON row",
      code: 'json_missing_field',
    );
  }
  if (value is! T) {
    throw DatabaseException(
      "Field '$key' has wrong type: expected $T, got ${value.runtimeType}",
      code: 'json_wrong_type',
    );
  }
  return value;
}

/// Reads an optional field from a JSON row. Returns `null` when the key is
/// absent or the value is null. Throws [DatabaseException] if the field is
/// present with the wrong type — a wrong type is a schema drift, not an
/// "absent field" case, so this fails loudly even on the "optional" path.
T? optionalField<T>(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! T) {
    throw DatabaseException(
      "Field '$key' has wrong type: expected $T?, got ${value.runtimeType}",
      code: 'json_wrong_type',
    );
  }
  return value;
}

/// Reads a numeric field as an `int`. Postgres `bigint`/`integer` columns
/// arrive as `int`; `numeric` columns can arrive as `int` or `double`
/// depending on PostgREST encoding. Accept both, coerce to `int`. Throws
/// [DatabaseException] on missing or non-numeric.
int requireInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw DatabaseException(
      "Missing required field '$key' in JSON row",
      code: 'json_missing_field',
    );
  }
  if (value is! num) {
    throw DatabaseException(
      "Field '$key' has wrong type: expected num, got ${value.runtimeType}",
      code: 'json_wrong_type',
    );
  }
  return value.toInt();
}

/// Reads a numeric field as a `double`. See [requireInt] for the num-coercion
/// rationale.
double requireDouble(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) {
    throw DatabaseException(
      "Missing required field '$key' in JSON row",
      code: 'json_missing_field',
    );
  }
  if (value is! num) {
    throw DatabaseException(
      "Field '$key' has wrong type: expected num, got ${value.runtimeType}",
      code: 'json_wrong_type',
    );
  }
  return value.toDouble();
}

/// Reads an ISO-8601 timestamp string and parses it. Throws
/// [DatabaseException] on missing, non-string, or unparseable.
DateTime requireDateTime(Map<String, dynamic> json, String key) {
  final raw = requireField<String>(json, key);
  try {
    return DateTime.parse(raw);
  } on FormatException catch (e) {
    throw DatabaseException(
      "Field '$key' is not a valid ISO-8601 timestamp: ${e.message}",
      code: 'json_bad_timestamp',
    );
  }
}

/// Optional variant of [requireDateTime]. Returns `null` for absent keys;
/// throws [DatabaseException] on present-but-malformed.
DateTime? optionalDateTime(Map<String, dynamic> json, String key) {
  final raw = optionalField<String>(json, key);
  if (raw == null) return null;
  try {
    return DateTime.parse(raw);
  } on FormatException catch (e) {
    throw DatabaseException(
      "Field '$key' is not a valid ISO-8601 timestamp: ${e.message}",
      code: 'json_bad_timestamp',
    );
  }
}
