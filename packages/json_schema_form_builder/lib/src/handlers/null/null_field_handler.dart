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
import '../../widgets/field_with_variants.dart';
import 'null_field.dart';
import 'null_field_state.dart';

/// The handler of `type: "null"` fields: builds NullFieldState and renders
/// a NullField.
class NullFieldHandler extends JsonFieldHandler<NullFieldState> {
  /// Creates the handler.
  const NullFieldHandler({
    required super.registryGetter,
  });

  @override
  Widget buildField({
    required BuildContext context,
    required NullFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return buildFieldWithVariants(
      context: context,
      fieldState: fieldState,
      displayContext: displayContext,
      onChanged: onChanged,
      contentBuilder: (onChanged) => NullField(
        fieldState: fieldState,
        onChanged: onChanged,
        absentAllowed: displayContext.absentAllowed,
      ),
    );
  }

  @override
  Future<NullFieldState> buildState(FieldBuildRequest request) async {
    final schema = request.schema;
    return NullFieldState(
      value: request.value,
      schema: schema is NullSchema ? schema : null,
      rootSchema: request.resolveContext.rootSchema,
      errors: request.errors,
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
    );
  }

  /// Null IS the canonical (and only) representation of the null type.
  /// Without it the switch-representation policy of the entry dialog seeds
  /// nothing when the previous value is incompatible, the built state carries
  /// an absent value, and committing the dialog cannot write the explicit
  /// JSON null the user selected.
  @override
  PresenceValue<dynamic>? get canonicalEmptyValue => const PresenceValue(null);

  /// The default wiring of this handler for a type-based registry: claims
  /// the `null` schema type and the Null value type.
  static JsonHandlerRegistration registration(JsonHandlerRegistry Function() registryGetter) => JsonHandlerRegistration(
    stateType: NullFieldState,
    handler: NullFieldHandler(registryGetter: registryGetter),
    valueTypes: const [Null],
    schemaTypes: const [JsonType.nil],
  );

  @override
  bool canEditValue(dynamic value) => value == null;

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameNull;

  @override
  bool matchesState(JsonFieldState state) => state is NullFieldState;
}
