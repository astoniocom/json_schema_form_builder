import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';

/// The state of a boolean field.
class BoolFieldState extends JsonFieldState<BooleanSchema> {
  /// Creates a boolean field state.
  const BoolFieldState({
    required super.value,
    required super.variants,
    required super.rootSchema,
    super.title,
    super.fieldAnnotations,
    super.matchedVariantIndices,
    super.errors,
    super.schema,
  });

  /// The value as a bool. Strict: only a real bool renders as the checkbox
  /// value, anything else shows the indeterminate state (with the raw value
  /// in displayValue). The single dynamic -> bool conversion of this state;
  /// handlers and widgets read it instead of inspecting [value]. Never
  /// throws: a wrong-typed value is a data/schema mismatch surfaced by
  /// validation, not a crash.
  bool? get typedValue {
    final raw = value.valueOrNull;
    return raw is bool ? raw : null;
  }

  @override
  BoolFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return BoolFieldState(
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
