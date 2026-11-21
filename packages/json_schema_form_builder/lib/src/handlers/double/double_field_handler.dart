import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:material_ui/material_ui.dart';

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
import 'double_field_state.dart';

/// The handler of number fields: builds DoubleFieldState and renders a
/// DoubleField.
class DoubleFieldHandler extends JsonFieldHandler<DoubleFieldState> {
  /// Creates the handler; [emptyValue] configures what a cleared field
  /// writes (absent by default, explicit null for nullable schemas).
  const DoubleFieldHandler({
    required super.registryGetter,
    this.emptyValue = const PresenceValue.absent(),
  });

  /// What a cleared field writes into the document; normalized per state
  /// (see normalizedEmptyValue: nullable schemas write an explicit null).
  final PresenceValue<dynamic> emptyValue;

  @override
  PresenceValue<dynamic>? variantEmptyValue(DoubleFieldState fieldState) => normalizedEmptyValue(fieldState, emptyValue);

  @override
  Widget buildField({
    required BuildContext context,
    required DoubleFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    final emptyValueNormalized = normalizedEmptyValue(fieldState, emptyValue);

    return buildFieldWithVariants(
      context: context,
      fieldState: fieldState,
      displayContext: displayContext,
      onChanged: onChanged,
      contentBuilder: (onChanged) => DoubleField(
        error: fieldState.errorsAsString,
        title: fieldState.title,
        helpText: fieldState.fieldAnnotations?.description,
        value: fieldState.typedValue,
        onChanged: onChanged == null ? null : (val) => onChanged(fieldState.copyWith(value: val == null ? emptyValueNormalized : PresenceValue(val))),
        required: fieldState.fieldAnnotations?.required ?? false,
        examples: fieldState.fieldAnnotations?.examples?.whereType<num>().toList(growable: false),
      ),
    );
  }

  @override
  Future<DoubleFieldState> buildState(FieldBuildRequest request) async {
    final schema = request.schema;
    return DoubleFieldState(
      value: request.value,
      schema: schema is NumberSchema ? schema : null,
      rootSchema: request.resolveContext.rootSchema,
      errors: request.errors,
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
    );
  }

  /// The default wiring of this handler for a type-based registry: claims
  /// the `number` schema type and the double value type.
  static JsonHandlerRegistration registration(JsonHandlerRegistry Function() registryGetter) => JsonHandlerRegistration(
    stateType: DoubleFieldState,
    handler: DoubleFieldHandler(registryGetter: registryGetter),
    valueTypes: const [double],
    schemaTypes: const [JsonType.num],
  );

  @override
  bool canEditValue(dynamic value) => dartTypeOfValue(value) == double;

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameDouble;

  @override
  bool matchesState(JsonFieldState state) {
    return state is DoubleFieldState;
  }
}
