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
import 'enum_field.dart';
import 'enum_field_state.dart';

/// The handler of select-like fields: builds EnumFieldState and renders an
/// EnumField. Selected by the registry for every schema with `enum` (or
/// pinned alternatives), regardless of the value type.
class EnumFieldHandler extends JsonFieldHandler<EnumFieldState> {
  /// Creates the handler.
  const EnumFieldHandler({
    required super.registryGetter,
  });

  @override
  PresenceValue<dynamic>? variantEmptyValue(EnumFieldState fieldState) => const PresenceValue.absent();

  @override
  Widget buildField({
    required BuildContext context,
    required EnumFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return buildFieldWithVariants(
      context: context,
      fieldState: fieldState,
      displayContext: displayContext,
      onChanged: onChanged,
      contentBuilder: (onChanged) => EnumField(
        fieldState: fieldState,
        displayContext: displayContext,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Future<EnumFieldState> buildState(FieldBuildRequest request) async {
    return EnumFieldState(
      value: request.value,
      schema: request.schema,
      enumValues: request.schema?.enumValues ?? const [],
      errors: request.errors,
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
      rootSchema: request.resolveContext.rootSchema,
    );
  }

  /// Claims no types (the registry selects this handler by the `enum`
  /// keyword, not by type) and is not pickable without a schema: there would
  /// be no enum values to pick from.
  static JsonHandlerRegistration registration(JsonHandlerRegistry Function() registryGetter) => JsonHandlerRegistration(
    stateType: EnumFieldState,
    handler: EnumFieldHandler(registryGetter: registryGetter),
    pickableWithoutSchema: false,
  );

  // Without a schema the editable values (enumValues) are unknown, so no
  // capability can be promised.
  @override
  bool canEditValue(dynamic value) => false;

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameEnum;

  @override
  bool matchesState(JsonFieldState state) => state is EnumFieldState;
}
