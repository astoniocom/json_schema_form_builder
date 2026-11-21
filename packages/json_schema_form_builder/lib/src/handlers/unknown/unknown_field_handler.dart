import 'package:material_ui/material_ui.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_build_request.dart';
import '../../models/field_context.dart';
import '../../models/json_field_handler.dart';
import '../../models/json_field_state.dart';
import '../../widgets/field_with_variants.dart';
import 'unknown_field.dart';
import 'unknown_field_state.dart';

/// The fallback handler for fields no registered handler accepts: builds
/// UnknownFieldState and renders the read-only UnknownField. Wired into the
/// registry as `unknownFieldHandler`, not registered for any type.
class UnknownFieldHandler extends JsonFieldHandler<UnknownFieldState> {
  /// Creates the handler.
  const UnknownFieldHandler({
    required super.registryGetter,
  });

  @override
  Widget buildField({
    required BuildContext context,
    required UnknownFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    return buildFieldWithVariants(
      context: context,
      fieldState: fieldState,
      displayContext: displayContext,
      onChanged: onChanged,
      contentBuilder: (_) => UnknownField(fieldState: fieldState),
    );
  }

  @override
  Future<UnknownFieldState> buildState(FieldBuildRequest request) async {
    return UnknownFieldState(
      value: request.value,
      schema: request.schema,
      errors: request.errors,
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
      rootSchema: request.resolveContext.rootSchema,
      type: request.schema?.type,
    );
  }

  // A read-only presenter of unsupported values, not an editor.
  @override
  bool canEditValue(dynamic value) => false;

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameUnknown;

  @override
  bool matchesState(JsonFieldState state) => state is UnknownFieldState;
}
