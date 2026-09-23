import 'package:collection/collection.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';
import '../../models/schema_values.dart';
import '../../models/type_matching.dart';
import 'object_field_entry.dart';

/// The state of an object field: one child state per rendered property plus
/// the pattern-property schemas for naming new entries.
class ObjectFieldState extends JsonFieldState<ObjectSchema> implements NodeState<String, JsonFieldState> {
  /// Creates an object field state.
  const ObjectFieldState({
    required this.children,
    required super.value,
    required super.variants,
    required super.title,
    required super.rootSchema,
    required this.fieldNamePatterns,
    super.fieldAnnotations,
    super.matchedVariantIndices,
    super.schema,
    super.errors,
  });

  @override
  final Map<String, ObjectFieldEntry> children;

  @override
  bool get childrenHasErrors => children.values.any((c) => c.hasErrors);

  /// The schema's `patternProperties`, compiled: a newly added property
  /// whose name matches a pattern gets the pattern's schema.
  final Map<RegExp, Schema> fieldNamePatterns;

  /// See the staleness contract on [JsonFieldState.copyWith]; [children]
  /// follows the same rule (a build-time snapshot, not refreshed by point
  /// writes).
  @override
  ObjectFieldState copyWith({
    PresenceValue<dynamic>? value,
    Map<String, ObjectFieldEntry>? children,
    List<JsonFieldState>? variants,
    Set<int>? matchedVariantIndices,
  }) {
    return ObjectFieldState(
      value: value ?? this.value,
      children: children ?? this.children,
      variants: variants ?? this.variants,
      matchedVariantIndices: matchedVariantIndices ?? this.matchedVariantIndices,
      title: title,
      fieldAnnotations: fieldAnnotations,
      schema: schema,
      errors: errors,
      rootSchema: rootSchema,
      fieldNamePatterns: fieldNamePatterns,
    );
  }

  @override
  ObjectFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return ObjectFieldState(
      value: value,
      children: children,
      variants: variants,
      matchedVariantIndices: matchedVariantIndices,
      title: title,
      fieldAnnotations: fieldAnnotations,
      schema: schema,
      errors: errors,
      rootSchema: rootSchema,
      fieldNamePatterns: fieldNamePatterns,
    );
  }

  /// Clears the object's value and every child state with it.
  @override
  ObjectFieldState clear() {
    final clearedChildren = {
      for (final entry in children.entries) entry.key: entry.value.clear(),
    };

    return copyWith(
      children: clearedChildren,
      value: const PresenceValue.absent(),
    );
  }

  /// Distributes [errors] by path: property errors go into the matching
  /// child states, root-path errors stay on the object itself.
  @override
  ObjectFieldState applyErrors(List<ValidationError> errors) {
    final resultChildren = {
      for (final child in children.entries)
        child.key: child.value.applyErrors(
          errors
              .where((e) => e.path.firstOrNull == child.key)
              .map((e) => ValidationError(e.error, path: e.path.sublist(1), details: e.details))
              .toList(growable: false),
        ),
    };

    final fieldErrors = errors.where((e) => e.path.isEmpty).toList(growable: false);
    // Even an empty fieldErrors list is kept: validation ran, the state is
    // "validated clean" (see JsonFieldState.errors).
    return ObjectFieldState(
      value: value,
      children: resultChildren,
      variants: variants,
      matchedVariantIndices: matchedVariantIndices,
      title: title,
      fieldAnnotations: fieldAnnotations,
      schema: schema,
      errors: fieldErrors,
      rootSchema: rootSchema,
      fieldNamePatterns: fieldNamePatterns,
    );
  }

  Map<String, ObjectFieldEntry> _mergeChildrenAfterVariantSwitch(ObjectFieldState oldState, ObjectFieldState newState) {
    final mergedChildren = Map<String, ObjectFieldEntry>.of(children);

    for (final MapEntry(:key, value: fieldEntry) in newState.children.entries) {
      var childState = fieldEntry.state;
      final PresenceValue<Object?> defaultValue = childState.fieldAnnotations?.defaultValue ?? const PresenceValue.absent();
      // The branch's discriminator field must be rewritten on EVERY switch,
      // even over an existing value: the user cannot edit it, so the value
      // written by the previously selected branch would otherwise stay
      // stale forever. Two spellings (both match rjsf's
      // sanitizeDataForNewSchema): a pinned schema ([schemaPinnedValue]:
      // `const` or a single-element `enum`), and the rjsf convention of a
      // readOnly field with a `default`.
      final PresenceValue<Object?> pinnedValue = schemaPinnedValue(childState.schema);
      final bool readOnlyDefault = (childState.fieldAnnotations?.readOnly ?? false) && defaultValue.present;
      final PresenceValue<Object?> discriminator = pinnedValue.present
          ? pinnedValue
          : readOnlyDefault
          ? defaultValue
          : const PresenceValue.absent();

      if (discriminator.present) {
        childState = childState.copyWith(value: PresenceValue(discriminator.valueOrNull));
      } else if (!childState.hasValue) {
        // Switching to an alternative is a user interaction extending the
        // object, so the branch's schema defaults seed its empty fields.
        if (!defaultValue.present) continue;
        childState = childState.copyWith(value: PresenceValue(defaultValue.valueOrNull));
      }
      mergedChildren[key] = ObjectFieldEntry(additional: mergedChildren[key]?.additional ?? true, state: childState);
    }

    final oldNotAdditionalChildrenKeys = oldState.children.entries.whereNot((mapEntry) => mapEntry.value.additional).map((mapEntry) => mapEntry.key);
    for (final key in oldNotAdditionalChildrenKeys) {
      final newFieldEntry = newState.children[key];

      if (newFieldEntry == null || newFieldEntry.additional) {
        final curFieldEntry = children[key];
        if (curFieldEntry != null && !curFieldEntry.additional) continue;
        mergedChildren.remove(key);
      }
    }

    return mergedChildren;
  }

  /// Merges [newChildren] into the current value instead of rebuilding it.
  ///
  /// `children` contain only the keys visible at this level: properties
  /// declared solely in anyOf/oneOf branches live in variants, extra keys can
  /// be hidden by the additionalProperties/displayMode policy. Rebuilding
  /// sValue from children (the old mapChildrenToValue approach) silently
  /// dropped every hidden key on any child edit.
  ///
  /// [removedKeys] lists keys the caller knows were deleted even though they
  /// are absent from both the old and the new children (e.g. a key cleared
  /// inside a variant).
  ObjectFieldState applyNewChildren({
    required Map<String, ObjectFieldEntry> newChildren,
    required PresenceValue<dynamic>? emptyValue,
    Set<String> removedKeys = const {},
  }) {
    final base = value.valueOrNull;
    final merged = <String, Object?>{if (base is Map) ...Map<String, Object?>.from(base)};

    // A key managed by the previous children set that disappeared from
    // newChildren was removed by the user.
    for (final key in children.keys) {
      if (!newChildren.containsKey(key)) merged.remove(key);
    }
    removedKeys.forEach(merged.remove);
    for (final entry in newChildren.entries) {
      if (entry.value.state.hasValue) {
        merged[entry.key] = entry.value.state.valueOrNull;
      } else {
        merged.remove(entry.key);
      }
    }

    return copyWith(
      value: (merged.isEmpty && emptyValue != null) ? emptyValue : PresenceValue(merged),
      children: newChildren,
    );
  }

  /// Applies a variant switch with object merge semantics: the old branch's
  /// keys leave the value, the new branch's children (and its pinned/default
  /// values) come in, everything else is kept (see ObjectFieldHandler.
  /// applyVariantSwitched).
  ObjectFieldState applyVariantSwitch({
    required ObjectFieldState oldState,
    required ObjectFieldState newState,
  }) {
    final mergedChildren = _mergeChildrenAfterVariantSwitch(oldState, newState);
    // Keys of the branch being switched away from must leave the value (they
    // are re-added below if the new branch sets them again).
    //
    // emptyValue is deliberately not applied here: choosing a branch is a
    // deliberate interaction and the document must reflect it, so a branch
    // with no values yields an explicit {} (matches react-jsonschema-form).
    // Collapsing to absent would drop the property's key -- and an array
    // item, which cannot be absent, would degrade to null.
    return applyNewChildren(
      newChildren: mergedChildren,
      emptyValue: null,
      removedKeys: oldState.children.keys.toSet(),
    );
  }

  Map<String, ObjectFieldEntry> _rebuildChildrenAfterVariantChanged(ObjectFieldState variantState) {
    final newChildren = Map.of(children);
    for (final childEntry in variantState.children.entries) {
      if (childEntry.value.state.hasValue) {
        newChildren[childEntry.key] = ObjectFieldEntry(
          additional: newChildren[childEntry.key]?.additional ?? true,
          state: childEntry.value.state,
        );
      } else {
        newChildren.remove(childEntry.key);
      }
    }
    return newChildren;
  }

  @override
  JsonFieldState<ObjectSchema> resolveVariantUpdate(
    JsonFieldState<Schema> variantState,
    List<JsonFieldState<Schema>> actualVariants,
    PresenceValue<dynamic>? emptyValue,
  ) {
    // The merge below serves declared anyOf/oneOf branches, which REFINE the
    // base object: a branch edit must not clobber keys the branch does not
    // manage. A synthesized type branch (see schemaHasOwnAlternatives) is
    // the whole editor of the whole value, so its write replaces the value
    // wholesale (the base behavior) — merging would make key removal
    // invisible: the removed key is gone from the branch's children (not
    // present-but-valueless), and the root children of an unconstrained
    // schema track no keys at all, so no merge rule would drop it.
    if (variantState is! ObjectFieldState || !schemaHasOwnAlternatives(schema)) {
      return super.resolveVariantUpdate(variantState, actualVariants, emptyValue);
    }

    final newChildren = _rebuildChildrenAfterVariantChanged(variantState);
    // A key cleared inside the variant may be missing from the root children
    // entirely (anyOf-branch-only property), so its removal must be explicit.
    final removedKeys = {
      for (final entry in variantState.children.entries)
        if (!entry.value.state.hasValue) entry.key,
    };

    return applyNewChildren(
      newChildren: newChildren,
      emptyValue: emptyValue,
      removedKeys: removedKeys,
    ).copyWith(variants: actualVariants);
  }

  /// Applies an edit of the child under [key]: stores the new child state
  /// and rebuilds the object's value from the children (an object emptied
  /// this way writes [emptyValue]).
  ObjectFieldState applyChildValueChange({
    required String key,
    required JsonFieldState newValue,
    required PresenceValue<dynamic> emptyValue,
  }) {
    final existingEntry = children[key];
    assert(existingEntry != null, 'applyChildValueChange: key "$key" not found among children.');
    if (existingEntry == null) return this;

    final List<MapEntry<String, ObjectFieldEntry>> newChildren = [];
    for (final childMapEntry in children.entries) {
      if (childMapEntry.key != key) {
        newChildren.add(childMapEntry);
        continue;
      }

      if (newValue.hasValue || !childMapEntry.value.additional) {
        newChildren.add(
          MapEntry(
            childMapEntry.key,
            ObjectFieldEntry(
              additional: childMapEntry.value.additional,
              state: newValue,
            ),
          ),
        );
      }
    }

    return applyNewChildren(newChildren: Map.fromEntries(newChildren), emptyValue: emptyValue);
  }
}
