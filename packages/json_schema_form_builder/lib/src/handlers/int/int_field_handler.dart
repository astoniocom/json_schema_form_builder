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
import 'int_field_state.dart';

/// The handler of integer fields: builds IntFieldState and renders an
/// IntField.
class IntFieldHandler extends JsonFieldHandler<IntFieldState> {
  /// Creates the handler; [emptyValue] configures what a cleared field
  /// writes (absent by default, explicit null for nullable schemas).
  const IntFieldHandler({
    required super.registryGetter,
    this.emptyValue = const PresenceValue.absent(),
  });

  /// What a cleared field writes into the document; normalized per state
  /// (see normalizedEmptyValue: nullable schemas write an explicit null).
  final PresenceValue<dynamic> emptyValue;

  @override
  PresenceValue<dynamic>? variantEmptyValue(IntFieldState fieldState) => normalizedEmptyValue(fieldState, emptyValue);

  @override
  Widget buildField({
    required BuildContext context,
    required IntFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    final emptyValueNormalized = normalizedEmptyValue(fieldState, emptyValue);

    return buildFieldWithVariants(
      context: context,
      fieldState: fieldState,
      displayContext: displayContext,
      onChanged: onChanged,
      contentBuilder: (onChanged) => IntField(
        error: fieldState.errorsAsString,
        title: fieldState.title,
        helpText: fieldState.fieldAnnotations?.description,
        value: fieldState.typedValue,
        onChanged: onChanged == null ? null : (val) => onChanged(fieldState.copyWith(value: val == null ? emptyValueNormalized : PresenceValue(val))),
        required: fieldState.fieldAnnotations?.required ?? false,
        examples: fieldState.fieldAnnotations?.examples?.whereType<int>().toList(growable: false),
      ),
    );
  }

  @override
  Future<IntFieldState> buildState(FieldBuildRequest request) async {
    final schema = request.schema;
    return IntFieldState(
      value: request.value,
      schema: schema is IntegerSchema ? schema : null,
      rootSchema: request.resolveContext.rootSchema,
      errors: request.errors,
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
    );
  }

  /// The default wiring of this handler for a type-based registry: claims
  /// the `integer` schema type and the int value type.
  static JsonHandlerRegistration registration(JsonHandlerRegistry Function() registryGetter) => JsonHandlerRegistration(
    stateType: IntFieldState,
    handler: IntFieldHandler(registryGetter: registryGetter),
    valueTypes: const [int],
    schemaTypes: const [JsonType.int],
  );

  @override
  bool canEditValue(dynamic value) => dartTypeOfValue(value) == int;

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameInt;

  @override
  bool matchesState(JsonFieldState state) => state is IntFieldState;
}
