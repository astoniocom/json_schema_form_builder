import 'package:flutter/material.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_build_request.dart';
import '../../models/field_context.dart';
import '../../models/json_field_handler.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registration.dart';
import '../../models/json_handler_registry.dart';
import '../../models/presence_value.dart';
import '../../widgets/field_with_variants.dart';
import 'raw_field.dart';
import 'raw_field_state.dart';

/// The handler of raw JSON fields: builds RawFieldState and renders a
/// RawField (free-form JSON text editing for any value).
class RawFieldHandler extends JsonFieldHandler<RawFieldState> {
  /// Creates the handler.
  const RawFieldHandler({
    required super.registryGetter,
  });

  @override
  PresenceValue<dynamic>? variantEmptyValue(RawFieldState fieldState) => const PresenceValue.absent();

  @override
  Widget buildField({
    required BuildContext context,
    required RawFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return buildFieldWithVariants(
      context: context,
      fieldState: fieldState,
      displayContext: displayContext,
      onChanged: onChanged,
      contentBuilder: (onChanged) => RawField(
        state: fieldState,
        onChanged: onChanged == null ? null : (val, parseError) => onChanged(fieldState.copyWith(value: val, parseError: PresenceValue(parseError))),
      ),
    );
  }

  @override
  Future<RawFieldState> buildState(FieldBuildRequest request) async {
    return RawFieldState(
      value: request.value,
      schema: request.schema,
      rootSchema: request.resolveContext.rootSchema,
      errors: request.errors,
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
    );
  }

  /// Claims no types: claiming any would collide with the concrete handler
  /// of that type and steal schema-less values from the typed editors. The
  /// raw editor is reached explicitly — picked by the user (it stays
  /// pickable without a schema) or wired as the registry's
  /// unknownFieldHandler substitute.
  static JsonHandlerRegistration registration(JsonHandlerRegistry Function() registryGetter) => JsonHandlerRegistration(
    stateType: RawFieldState,
    handler: RawFieldHandler(registryGetter: registryGetter),
  );

  // A free-form JSON editor edits any value, including an explicit null.
  @override
  bool canEditValue(dynamic value) => true;

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameRaw;

  @override
  bool matchesState(JsonFieldState state) => state is RawFieldState;
}
