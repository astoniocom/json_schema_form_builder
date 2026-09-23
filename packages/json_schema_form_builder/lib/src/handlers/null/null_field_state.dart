import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';

/// The state of a `type: "null"` field.
class NullFieldState extends JsonFieldState<NullSchema> {
  /// Creates a null field state.
  const NullFieldState({
    required super.value,
    required super.variants,
    required super.rootSchema,
    super.title,
    super.fieldAnnotations,
    super.matchedVariantIndices,
    super.schema,
    super.errors,
  });

  @override
  NullFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return NullFieldState(
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
