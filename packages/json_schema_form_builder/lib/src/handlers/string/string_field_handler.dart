import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_build_request.dart';
import '../../models/field_context.dart';
import '../../models/json_field_handler.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registration.dart';
import '../../models/json_handler_registry.dart';
import '../../models/presence_value.dart';
import '../../models/type_matching.dart';
import '../../widgets/field_with_variants.dart';
import 'string_field_state.dart';

/// The handler of string fields: builds StringFieldState and renders the
/// editor matching the schema's `format` — date, time, date-time and
/// data-url get dedicated pickers, everything else a plain text field.
class StringFieldHandler extends JsonFieldHandler<StringFieldState> {
  /// Creates the handler; [emptyValue] configures what a cleared field
  /// writes (absent by default, explicit null for nullable schemas).
  const StringFieldHandler({
    required super.registryGetter,
    this.emptyValue = const PresenceValue.absent(),
    this.filePicker,
  });

  /// What a cleared field writes into the document; normalized per state
  /// (see normalizedEmptyValue: nullable schemas write an explicit null).
  final PresenceValue<dynamic> emptyValue;

  /// Host-supplied picker for `format: "data-url"` fields. The package pulls
  /// in no file-picking plugin; without a picker such fields render with a
  /// disabled pick button.
  final DataUrlFilePicker? filePicker;

  @override
  PresenceValue<dynamic>? variantEmptyValue(StringFieldState fieldState) => normalizedEmptyValue(fieldState, emptyValue);

  @override
  Widget buildField({
    required BuildContext context,
    required StringFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return buildFieldWithVariants(
      context: context,
      fieldState: fieldState,
      displayContext: displayContext,
      onChanged: onChanged,
      contentBuilder: (onChanged) => switch (fieldState.format) {
        'date' => buildStringDateField(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged),
        'time' => buildStringTimeField(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged),
        'date-time' => buildStringDateTimeField(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged),
        'data-url' => buildStringDataUrlField(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged),
        _ => buildStringField(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged),
      },
    );
  }

  /// The editor for `format: "date"`; @protected so subclasses can replace
  /// one format's editor without re-implementing the dispatch.
  @protected
  Widget buildStringDateField({
    required BuildContext context,
    required StringFieldState fieldState,
    required FieldDisplayContext displayContext,

    void Function(JsonFieldState)? onChanged,
  }) {
    return StringDateField(
      error: fieldState.errorsAsString,
      title: fieldState.title,
      helpText: fieldState.fieldAnnotations?.description,
      value: fieldState.typedValue,
      required: fieldState.fieldAnnotations?.required ?? false,
      onChanged: onChanged == null
          ? null
          : (val) => onChanged(fieldState.copyWith(value: val.isNotEmpty ? PresenceValue(val) : normalizedEmptyValue(fieldState, emptyValue))),
      examples: fieldState.fieldAnnotations?.examples?.whereType<String>().toList(growable: false),
    );
  }

  /// The editor for `format: "date-time"` (see [buildStringDateField] on
  /// overriding).
  @protected
  Widget buildStringDateTimeField({
    required BuildContext context,
    required StringFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return StringDateTimeField(
      error: fieldState.errorsAsString,
      title: fieldState.title,
      helpText: fieldState.fieldAnnotations?.description,
      value: fieldState.typedValue,
      required: fieldState.fieldAnnotations?.required ?? false,
      onChanged: onChanged == null
          ? null
          : (val) => onChanged(fieldState.copyWith(value: val.isNotEmpty ? PresenceValue(val) : normalizedEmptyValue(fieldState, emptyValue))),
      examples: fieldState.fieldAnnotations?.examples?.whereType<String>().toList(growable: false),
    );
  }

  /// The editor for `format: "time"` (see [buildStringDateField] on
  /// overriding).
  @protected
  Widget buildStringTimeField({
    required BuildContext context,
    required StringFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return StringTimeField(
      error: fieldState.errorsAsString,
      title: fieldState.title,
      helpText: fieldState.fieldAnnotations?.description,
      value: fieldState.typedValue,
      required: fieldState.fieldAnnotations?.required ?? false,
      onChanged: onChanged == null
          ? null
          : (val) => onChanged(fieldState.copyWith(value: val.isNotEmpty ? PresenceValue(val) : normalizedEmptyValue(fieldState, emptyValue))),
      examples: fieldState.fieldAnnotations?.examples?.whereType<String>().toList(growable: false),
    );
  }

  /// The editor for `format: "data-url"`, wired to [filePicker] (see
  /// [buildStringDateField] on overriding).
  @protected
  Widget buildStringDataUrlField({
    required BuildContext context,
    required StringFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return StringDataUrlField(
      error: fieldState.errorsAsString,
      title: fieldState.title,
      helpText: fieldState.fieldAnnotations?.description,
      value: fieldState.typedValue,
      required: fieldState.fieldAnnotations?.required ?? false,
      pickFile: filePicker,
      noFileSelectedHint: jsonFormLocalizationsOf(context).noFileSelectedHint,
      onChanged: onChanged == null
          ? null
          : (val) => onChanged(fieldState.copyWith(value: val.isNotEmpty ? PresenceValue(val) : normalizedEmptyValue(fieldState, emptyValue))),
    );
  }

  /// The editor for strings without a format-specific one (see
  /// [buildStringDateField] on overriding).
  @protected
  Widget buildStringField({
    required BuildContext context,
    required StringFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return StringField(
      error: fieldState.errorsAsString,
      title: fieldState.title,
      helpText: fieldState.fieldAnnotations?.description,
      value: fieldState.typedValue,
      required: fieldState.fieldAnnotations?.required ?? false,
      maxLength: fieldState.schema?.maxLength,
      onChanged: onChanged == null
          ? null
          : (newVal) => onChanged(fieldState.copyWith(value: newVal.isNotEmpty ? PresenceValue(newVal) : normalizedEmptyValue(fieldState, emptyValue))),
      examples: fieldState.fieldAnnotations?.examples?.whereType<String>().toList(growable: false),
    );
  }

  @override
  Future<StringFieldState> buildState(FieldBuildRequest request) async {
    final schema = request.schema;
    final stringSchema = schema is StringSchema ? schema : null;

    return StringFieldState(
      value: request.value,
      schema: stringSchema,
      errors: request.errors,
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
      rootSchema: request.resolveContext.rootSchema,
      format: stringSchema?.format,
    );
  }

  /// The default wiring of this handler for a type-based registry: claims
  /// the `string` schema type and the String value type.
  static JsonHandlerRegistration registration(JsonHandlerRegistry Function() registryGetter, {DataUrlFilePicker? filePicker}) => JsonHandlerRegistration(
    stateType: StringFieldState,
    handler: StringFieldHandler(registryGetter: registryGetter, filePicker: filePicker),
    valueTypes: const [String],
    schemaTypes: const [JsonType.string],
  );

  @override
  bool canEditValue(dynamic value) => dartTypeOfValue(value) == String;

  @override
  PresenceValue<dynamic>? get canonicalEmptyValue => const PresenceValue('');

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameString;

  @override
  bool matchesState(JsonFieldState state) => state is StringFieldState;
}
