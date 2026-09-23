import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';

/// The state of an integer field.
class IntFieldState extends JsonFieldState<IntegerSchema> {
  /// Creates an integer field state.
  const IntFieldState({
    required super.value,
    required super.variants,
    required super.rootSchema,
    super.title,
    super.fieldAnnotations,
    super.matchedVariantIndices,
    super.schema,
    super.errors,
  });

  /// The value as an int: an int as is; a double only when it is an exact
  /// integer representable in int64 -- toInt() throws on infinity and
  /// silently saturates values beyond the int64 range (e.g. 1e30 ->
  /// 9223372036854775807), which would display garbage for large numbers
  /// coming from JSON. The single dynamic -> int conversion of this state;
  /// handlers and widgets read it instead of inspecting [value].
  int? get typedValue {
    final raw = value.valueOrNull;
    if (raw is int) return raw;
    const maxInt64AsDouble = 9223372036854775808.0; // 2^63
    if (raw is double && raw.isFinite && raw >= -maxInt64AsDouble && raw < maxInt64AsDouble && raw == raw.roundToDouble()) {
      return raw.toInt();
    }
    return null;
  }

  @override
  IntFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return IntFieldState(
      value: value,
      variants: variants,
      matchedVariantIndices: matchedVariantIndices,
      rootSchema: rootSchema,
      title: title,
      schema: schema,
      fieldAnnotations: fieldAnnotations,
      errors: errors,
    );
  }
}
