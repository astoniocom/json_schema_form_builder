import 'package:flutter/material.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/cycle_field_state.dart';
import '../../models/field_build_request.dart';
import '../../models/field_context.dart';
import '../../models/json_field_handler.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registration.dart';
import '../../models/json_handler_registry.dart';
import 'cycle_field.dart';

/// Renders the fields collapsed by the registry's cycle guard (see
/// [CycleFieldState]). Never selected by schema or value dispatch — the
/// states are built directly by JsonHandlerRegistry.buildState — so its
/// registration claims no types and is not pickable; it exists purely for
/// the render-time state dispatch (handlerForField).
class CycleFieldHandler extends JsonFieldHandler<CycleFieldState> {
  /// Creates the handler.
  const CycleFieldHandler({required super.registryGetter});

  /// The default wiring of this handler for a type-based registry: only the
  /// state-type dispatch, no type claims, not pickable.
  static JsonHandlerRegistration registration(JsonHandlerRegistry Function() registryGetter) => JsonHandlerRegistration(
    stateType: CycleFieldState,
    handler: CycleFieldHandler(registryGetter: registryGetter),
    pickableWithoutSchema: false,
  );

  @override
  Widget buildField({
    required BuildContext context,
    required CycleFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return CycleField(
      fieldState: fieldState,
      registry: registry,
      displayContext: displayContext,
      onChanged: onChanged,
    );
  }

  /// The guard builds [CycleFieldState]s itself; this construction exists
  /// for completeness of the state-builder contract (e.g. custom registries
  /// dispatching manually).
  @override
  Future<CycleFieldState> buildState(FieldBuildRequest request) async {
    return CycleFieldState(
      value: request.value,
      rootSchema: request.resolveContext.rootSchema,
      expandedRefs: request.resolveContext.expandedRefs,
      schema: request.schema,
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      errors: request.errors,
    );
  }

  // A collapsed placeholder, not an editor.
  @override
  bool canEditValue(dynamic value) => false;

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameUnknown;

  @override
  bool matchesState(JsonFieldState state) => state is CycleFieldState;
}
