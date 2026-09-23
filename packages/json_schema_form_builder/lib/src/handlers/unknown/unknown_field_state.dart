import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';

/// The state of a field the registry could not dispatch: no registered
/// handler accepted the schema or the value.
class UnknownFieldState extends JsonFieldState {
  /// Creates an unknown field state.
  const UnknownFieldState({
    required super.value,
    required super.variants,
    required super.rootSchema,
    super.title,
    super.fieldAnnotations,
    super.matchedVariantIndices,
    super.schema,
    super.errors,
    this.type,
  });

  /// What the dispatch failed on (a schema type name or a Dart runtimeType),
  /// shown as the field label when the schema gives no title.
  final Object? type;

  @override
  UnknownFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return UnknownFieldState(
      value: value,
      variants: variants,
      matchedVariantIndices: matchedVariantIndices,
      rootSchema: rootSchema,
      title: title,
      schema: schema,
      fieldAnnotations: fieldAnnotations,
      errors: errors,
      type: type,
    );
  }
}
