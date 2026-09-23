import 'package:flutter/foundation.dart' show protected;
import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'field_context.dart';
import 'json_field_renderer.dart';
import 'json_field_state.dart';
import 'json_field_state_builder.dart';
import 'json_handler_registry.dart';
import 'presence_value.dart';
import 'schema_values.dart';
import 'type_matching.dart';

/// A field handler: the domain half ([JsonFieldStateBuilder]) plus the
/// presentation half ([JsonFieldRenderer]) in one class. The registry's
/// state-building pipeline depends only on the builder interface; UI code
/// depends only on the renderer one. The Variant switcher composition lives
/// in the widgets layer (`widgets/field_with_variants.dart`), so this file
/// stays free of widget imports.
///
/// What remains on the base class besides the two interfaces are the
/// variant WRITE policies ([applyVariantUpdated], [applyVariantSwitched]):
/// domain rules on the state, invoked from the widgets layer. Building the
/// variants is not the handler's job — the registry pipeline delivers them
/// pre-computed in the request (FieldBuildRequest.variants).
abstract class JsonFieldHandler<FS extends JsonFieldState> extends FieldHandler<FS, JsonFieldState, FieldDisplayContext>
    implements JsonFieldStateBuilder<FS>, JsonFieldRenderer<FS> {
  /// Creates a handler bound to the registry returned by [registryGetter].
  const JsonFieldHandler({required this.registryGetter});

  /// Returns the owning registry. A getter (not a direct reference) because
  /// the handlers and the registry are constructed mutually recursively:
  /// the registry's tables hold the handlers, the handlers dispatch children
  /// back through the registry.
  final JsonHandlerRegistry Function() registryGetter;

  /// The registry this handler dispatches child fields through.
  JsonHandlerRegistry get registry => registryGetter();

  /// The value written by a variant update when the selected variant carries
  /// no value. Null keeps the current value (see
  /// [JsonFieldState.resolveVariantUpdate]).
  PresenceValue<dynamic>? variantEmptyValue(FS fieldState) => null;

  /// Applies a state change of the selected variant alternative. Override to
  /// customize (see ObjectFieldHandler for merge semantics and out-of-range
  /// reporting).
  ///
  /// Public (not @protected): this is the write policy of the field, wired
  /// into the Variant widget by the `FieldWithVariants` extension in the
  /// widgets layer.
  void applyVariantUpdated({
    required int index,
    required JsonFieldState variantState,
    required FS fieldState,
    required FieldDisplayContext displayContext,
    required void Function(JsonFieldState) onChanged,
  }) {
    onChanged(fieldState.applyVariantUpdate(index, variantState, variantEmptyValue(fieldState)));
  }

  /// Applies switching to the variant alternative at [newIndex].
  ///
  /// Switching is a user interaction that extends the JSON document. When the
  /// target alternative pins the value ([schemaPinnedValue]: `const` or a
  /// single-element `enum`), that value is written unconditionally (the old
  /// alternative's value cannot satisfy the new one). Otherwise, when the
  /// alternative carries no value, its schema `default`
  /// ([FieldAnnotations.defaultValue]) is written; a container alternative
  /// without one still writes its empty value ({} / [], see
  /// containerEmptyValue) so the selection survives rebuilds.
  ///
  /// Besides the parent value, the write refreshes the target alternative's
  /// state with the written value, so the branch rendered below the switcher
  /// matches the document instead of keeping the state built for the previous
  /// value (e.g. a branch with a `default` shows that default right away).
  ///
  /// [JsonFieldState.matchedVariantIndices] is deliberately NOT updated: the
  /// live selection is owned by the Variant widget, because the user's intent
  /// is not derivable from the data (a partially filled branch may not match
  /// its schema yet while the value still matches another branch). [oldIndex]
  /// (null when nothing was selected before) is ignored by this base
  /// implementation and exists for overrides — ObjectFieldHandler needs the
  /// branch being switched away from for its merge semantics.
  ///
  /// Public (not @protected) for the same reason as [applyVariantUpdated].
  void applyVariantSwitched({
    required int? oldIndex,
    required int newIndex,
    required FS fieldState,
    required void Function(JsonFieldState) onChanged,
  }) {
    final variants = fieldState.variants;
    if (variants == null || newIndex < 0 || newIndex >= variants.length) {
      assert(false, 'Invalid variant index $newIndex');
      return;
    }

    final newState = variants[newIndex];
    // The shared switch-representation policy (see switchRepresentationValue):
    // pinned → branch value → schema seed. No admits gate (the branch schema
    // IS the representation). The emptySeed materializes CONTAINER branches
    // ({} / [], rjsf's getDefaultFormState parity — see containerEmptyValue):
    // without it the selection would not survive a dialog roundtrip, because
    // the committed value (absent) matches a different branch on rebuild.
    // Untouched SCALAR branches stay absent (also rjsf parity).
    final containerSeed = containerEmptyValue(newState.schema, rootSchema: fieldState.rootSchema);
    final PresenceValue<dynamic> newValue = switchRepresentationValue(
      targetSchema: newState.schema,
      currentValue: newState.value,
      rootSchema: fieldState.rootSchema,
      emptySeed: containerSeed.present ? PresenceValue<dynamic>(containerSeed.valueOrNull) : null,
    );

    final variantsCopy = List<JsonFieldState<Schema>>.of(variants);
    variantsCopy[newIndex] = newState.copyWith(value: newValue);

    onChanged(fieldState.copyWith(value: newValue, variants: variantsCopy));
  }

  /// Shared write policy: for nullable-typed schemas (type: [..., "null"])
  /// clearing a field writes an explicit JSON null instead of removing the
  /// key.
  @protected
  PresenceValue<dynamic> normalizedEmptyValue(JsonFieldState fieldState, PresenceValue<dynamic> emptyValue) {
    return isNullableSchema(fieldState.schema) ? const PresenceValue(null) : emptyValue;
  }

  /// The empty JSON representation of this handler's field type (e.g. `""`
  /// for a string), used when a cleared field must stay present in the
  /// document: an additional property exists only while its key is in the
  /// JSON, and an array item cannot be absent at all (it would degrade to
  /// null), so clearing must not act as removal (that is what the remove
  /// button is for).
  ///
  /// Null when the type has no empty representation (e.g. a number): the
  /// clearing write is then ignored and the document keeps the previous
  /// value, the widget holding the empty input locally.
  ///
  /// Unlike the configurable `emptyValue` of concrete handlers (the write
  /// policy for an ordinary clearing), this is a fixed fact about the type.
  @override
  PresenceValue<dynamic>? get canonicalEmptyValue => null;
}
