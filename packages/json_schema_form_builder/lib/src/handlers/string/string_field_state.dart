import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';

/// The state of a string field; [format] selects the editor (date, time,
/// date-time, data-url or plain text).
class StringFieldState extends JsonFieldState<StringSchema> {
  /// Creates a string field state.
  const StringFieldState({
    required super.value,
    required super.variants,
    required super.rootSchema,
    super.title,
    super.fieldAnnotations,
    super.matchedVariantIndices,
    super.schema,
    super.errors,
    this.format,
  });

  /// The schema's `format`, copied out so rendering needs no schema access.
  final String? format;

  /// The value as a String. Deliberately lenient: a non-string value renders
  /// via toString instead of disappearing from the text field, so a
  /// data/schema mismatch stays visible to the user (validation reports it;
  /// editing writes back a String). The single dynamic -> String conversion
  /// of this state; handlers and widgets read it instead of inspecting
  /// [value].
  String? get typedValue => value.valueOrNull?.toString();

  @override
  StringFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return StringFieldState(
      value: value,
      variants: variants,
      matchedVariantIndices: matchedVariantIndices,
      rootSchema: rootSchema,
      title: title,
      schema: schema,
      fieldAnnotations: fieldAnnotations,
      errors: errors,
      format: format,
    );
  }
}
