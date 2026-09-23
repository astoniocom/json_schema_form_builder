import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';

import '../models/field_context.dart';
import '../models/json_field_handler.dart';
import '../models/json_field_state.dart';
import 'variant_switcher.dart';

/// Presentation-side composition of the anyOf/oneOf alternatives switcher.
///
/// Lives in the widgets layer (not on the handler base class) so that
/// `models/json_field_handler.dart` does not import widgets: the handler owns
/// the write policies ([JsonFieldHandler.applyVariantUpdated],
/// [JsonFieldHandler.applyVariantSwitched]), this extension owns the wiring
/// of those policies into the [VariantSwitcher] widget.
extension FieldWithVariants<FS extends JsonFieldState> on JsonFieldHandler<FS> {
  /// The VariantSwitcher for [fieldState], wired to this handler's write
  /// policies; null when the state has no variants.
  Widget? buildVariant({
    required BuildContext context,
    required FS fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    if (fieldState.variants?.isEmpty ?? true) return null;

    final effectiveOnChanged = onChanged == null || (fieldState.fieldAnnotations?.readOnly ?? false) ? null : onChanged;

    return VariantSwitcher(
      fieldState: fieldState,
      handlerRegistry: registry,
      displayContext: displayContext,
      onChanged: effectiveOnChanged == null
          ? null
          : (index, variantState) => applyVariantUpdated(
              index: index,
              variantState: variantState,
              fieldState: fieldState,
              displayContext: displayContext,
              onChanged: effectiveOnChanged,
            ),
      onVariantSwitched: effectiveOnChanged == null
          ? null
          : (fromIndex, toIndex) => applyVariantSwitched(
              oldIndex: fromIndex,
              newIndex: toIndex,
              fieldState: fieldState,
              onChanged: effectiveOnChanged,
            ),
    );
  }

  /// Shared composition for scalar handlers.
  ///
  /// Without anyOf/oneOf alternatives returns the widget built by
  /// [contentBuilder]. With alternatives the content is hidden — the selected
  /// alternative behind the [VariantSwitcher] switcher renders the same value, so
  /// showing both would duplicate the field — and the switcher is framed by
  /// [EditorGroup] with the same policy as the object/array editors (frame
  /// with the title as label inside a dialog, plain expanded layout with a
  /// title row otherwise).
  ///
  /// [contentBuilder] receives the read-only-normalized callback: null when
  /// the caller passed no callback or the field is read-only
  /// (fieldAnnotations.readOnly, e.g. a const-pinned schema), so content
  /// widgets must not re-check readOnly.
  Widget buildFieldWithVariants({
    required BuildContext context,
    required FS fieldState,
    required FieldDisplayContext displayContext,
    required Widget Function(void Function(JsonFieldState)? onChanged) contentBuilder,
    void Function(JsonFieldState)? onChanged,
  }) {
    if (fieldState.variants?.isNotEmpty ?? false) {
      return EditorGroup(
        title: fieldState.title,
        helpText: fieldState.fieldAnnotations?.description,
        errors: fieldState.errors?.map((e) => e.toErrorString()) ?? const [],
        content: buildVariant(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged),
        view: displayContext.editorGroupView,
      );
    }

    final effectiveOnChanged = onChanged == null || (fieldState.fieldAnnotations?.readOnly ?? false) ? null : onChanged;
    return contentBuilder(effectiveOnChanged);
  }
}
