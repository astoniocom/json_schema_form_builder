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
import '../../utils/utils.dart';
import '../../widgets/field_with_variants.dart';
import 'bool_field_state.dart';

/// The handler of boolean fields: builds BoolFieldState and renders a
/// BoolField (checkbox).
class BoolFieldHandler extends JsonFieldHandler<BoolFieldState> {
  /// Creates the handler; [emptyValue] configures what a cleared field
  /// writes (absent by default).
  const BoolFieldHandler({
    required super.registryGetter,
    this.emptyValue = const PresenceValue.absent(),
  });

  /// What a cleared field (the tristate null) writes into the document.
  final PresenceValue<dynamic> emptyValue;

  @override
  PresenceValue<dynamic>? variantEmptyValue(BoolFieldState fieldState) => emptyValue;

  @override
  Widget buildField({
    required BuildContext context,
    required BoolFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    final hasRawValue = fieldState.valueOrNull != null;
    final emptyValueNormalized = normalizedEmptyValue(fieldState, emptyValue);

    // The checkbox cycles through the third (null) state only when the
    // schema admits null as a value; otherwise a click after `true` would
    // clear the field (and for an additional property destroy it).
    final tristate = isNullableSchema(fieldState.schema);

    return buildFieldWithVariants(
      context: context,
      fieldState: fieldState,
      displayContext: displayContext,
      onChanged: onChanged,
      contentBuilder: (onChanged) => BoolField(
        error: fieldState.errorsAsString,
        title: fieldState.title,
        helpText: fieldState.fieldAnnotations?.description,
        value: fieldState.typedValue,
        onChanged: onChanged == null ? null : (val) => onChanged(fieldState.copyWith(value: val == null ? emptyValueNormalized : PresenceValue(val))),
        required: fieldState.fieldAnnotations?.required ?? false,
        tristate: tristate,
        displayValue: hasRawValue ? valueAsString(fieldState.value) : null,
      ),
    );
  }

  @override
  Future<BoolFieldState> buildState(FieldBuildRequest request) async {
    final schema = request.schema;
    return BoolFieldState(
      value: request.value,
      schema: schema is BooleanSchema ? schema : null,
      rootSchema: request.resolveContext.rootSchema,
      errors: request.errors,
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
    );
  }

  /// The default wiring of this handler for a type-based registry: claims
  /// the `boolean` schema type and the bool value type.
  static JsonHandlerRegistration registration(JsonHandlerRegistry Function() registryGetter) => JsonHandlerRegistration(
    stateType: BoolFieldState,
    handler: BoolFieldHandler(registryGetter: registryGetter),
    valueTypes: const [bool],
    schemaTypes: const [JsonType.boolean],
  );

  @override
  bool canEditValue(dynamic value) => dartTypeOfValue(value) == bool;

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameBool;

  @override
  bool matchesState(JsonFieldState state) {
    return state is BoolFieldState;
  }
}
