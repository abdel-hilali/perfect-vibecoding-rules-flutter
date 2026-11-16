/// The JSON edge (F5, F15): the only place where untyped values are read.
///
/// Each reader checks the type and throws a [JsonFieldException] (a FormatException) on a missing or wrong field,
/// so a bad payload becomes a ValidationFailure in the repository, or one skipped row, never a TypeError.
library;

typedef JsonMap = Map<String, Object?>;

class JsonFieldException extends FormatException {
  JsonFieldException(String field, String expected)
    : super('Field "$field": expected $expected');
}

/// A required, non-empty string.
String stringOf(JsonMap json, String key) {
  final value = json[key];
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw JsonFieldException(key, 'a non-empty string');
}

/// An optional string: null when absent, an error when present with another type.
String? stringOrNull(JsonMap json, String key) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is String) {
    return value;
  }
  throw JsonFieldException(key, 'a string or null');
}

/// A required whole number. Some backends send 12.0 for 12: accepted; 12.5 is not.
int intOf(JsonMap json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is double && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw JsonFieldException(key, 'a whole number');
}

/// A required ISO 8601 date, kept in UTC as sent; widgets show it in local time.
DateTime dateOf(JsonMap json, String key) {
  final value = json[key];
  final date = value is String ? DateTime.tryParse(value) : null;
  if (date == null) {
    throw JsonFieldException(key, 'an ISO 8601 date');
  }
  return date;
}

/// A required list. Its items stay untyped: the caller parses each one and skips a bad row.
List<Object?> listOf(JsonMap json, String key) {
  final value = json[key];
  if (value is List<Object?>) {
    return value;
  }
  throw JsonFieldException(key, 'a list');
}

/// [value] as a JSON object, such as one row of a list.
JsonMap asJsonMap(Object? value, String what) {
  if (value is JsonMap) {
    return value;
  }
  throw JsonFieldException(what, 'an object');
}
