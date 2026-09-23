import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';

/// The state of a raw JSON field: any value edited as JSON text.
class RawFieldState extends JsonFieldState {
  /// Creates a raw field state.
  const RawFieldState({
    required super.value,
    required super.variants,
    required super.rootSchema,
    super.title,
    super.fieldAnnotations,
    super.matchedVariantIndices,
    super.schema,
    super.errors,
    this.parseError,
  });

  /// Transient editor fact: the text currently in the raw editor is not
  /// parseable JSON (localized message), so [value] still holds the last
  /// successfully parsed value. Kept in the state so that validity-gated UI
  /// (the OK buttons of the entry/add dialogs) sees the field as invalid:
  /// [applyErrors] folds it into the validation errors.
  final String? parseError;

  @override
  RawFieldState applyErrors(List<ValidationError> errors) {
    final parseErrorLoc = parseError;
    if (parseErrorLoc == null) return super.applyErrors(errors) as RawFieldState;

    return super.applyErrors([
          ...errors,
          ValidationError(ValidationErrorType.custom, path: const [], details: parseErrorLoc),
        ])
        as RawFieldState;
  }

  @override
  RawFieldState copyWith({
    PresenceValue<dynamic>? value,
    List<JsonFieldState>? variants,
    Set<int>? matchedVariantIndices,
    PresenceValue<String?>? parseError,
  }) {
    return RawFieldState(
      value: value ?? this.value,
      variants: variants ?? this.variants,
      matchedVariantIndices: matchedVariantIndices ?? this.matchedVariantIndices,
      rootSchema: rootSchema,
      title: title,
      schema: schema,
      fieldAnnotations: fieldAnnotations,
      errors: errors,
      parseError: parseError != null ? parseError.valueOrNull : this.parseError,
    );
  }

  @override
  RawFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return RawFieldState(
      value: value,
      variants: variants,
      matchedVariantIndices: matchedVariantIndices,
      rootSchema: rootSchema,
      title: title,
      schema: schema,
      fieldAnnotations: fieldAnnotations,
      errors: errors,
      parseError: parseError,
    );
  }
}
