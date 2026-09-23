import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';

/// The state of a select-like field (`enum`, or alternatives with pinned
/// values).
class EnumFieldState extends JsonFieldState<Schema> {
  /// Creates an enum field state.
  const EnumFieldState({
    required super.value,
    required super.variants,
    required super.rootSchema,
    required this.enumValues,
    super.title,
    super.fieldAnnotations,
    super.matchedVariantIndices,
    super.errors,
    super.schema,
  });

  /// The admitted values, in schema order.
  final List<Object?> enumValues;

  @override
  EnumFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return EnumFieldState(
      value: value,
      variants: variants,
      matchedVariantIndices: matchedVariantIndices,
      title: title,
      fieldAnnotations: fieldAnnotations,
      schema: schema,
      errors: errors,
      rootSchema: rootSchema,
      enumValues: enumValues,
    );
  }
}
