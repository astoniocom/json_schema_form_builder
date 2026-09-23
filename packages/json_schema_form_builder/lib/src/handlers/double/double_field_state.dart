import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';

/// The state of a number field.
class DoubleFieldState extends JsonFieldState<NumberSchema> {
  /// Creates a number field state.
  const DoubleFieldState({
    required super.value,
    required super.variants,
    required super.rootSchema,
    super.title,
    super.fieldAnnotations,
    super.matchedVariantIndices,
    super.schema,
    super.errors,
  });

  /// The value as a double. Any num converts: JSON has one number type, so
  /// `1` parses to a Dart int even under a `type: number` schema. The single
  /// dynamic -> double conversion of this state; handlers and widgets read it
  /// instead of inspecting [value].
  double? get typedValue {
    final raw = value.valueOrNull;
    return raw is num ? raw.toDouble() : null;
  }

  @override
  DoubleFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return DoubleFieldState(
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
