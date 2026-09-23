import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:meta/meta.dart';

import 'presence_value.dart';

/// The presentation annotations of a field, extracted from its resolved
/// schema (description, examples, required, default, readOnly). Grouped into
/// one object to reduce the number of properties in copyWith and the number
/// of properties passed down the chain.
class FieldAnnotations {
  /// Creates the annotations bundle.
  FieldAnnotations({
    this.description,
    this.examples,
    this.required,
    this.defaultValue = const PresenceValue.absent(),
    this.readOnly = false,
  });

  /// The schema's `description`, shown as the field's helper text.
  final String? description;

  /// The schema's `examples`, offered by editors that support a dropdown.
  final List<Object?>? examples;

  /// Whether the parent schema lists this field in `required`; null when
  /// the context does not say (e.g. a root field).
  final bool? required;

  /// The schema's `default`; absent when the schema declares none.
  final PresenceValue<Object?> defaultValue;

  /// Whether the field must not be edited: the schema's `readOnly`, or a
  /// `const`-pinned value (see JsonHandlerRegistry for the exact rule).
  final bool readOnly;
}

/// The immutable state of one field of the form: the value, the resolved
/// schema fragment it was built from, the validation result, and the
/// anyOf/oneOf variant machinery. Concrete subclasses (StringFieldState,
/// ObjectFieldState, ...) add their type-specific parts.
///
/// States are built by JsonHandlerRegistry.buildState, rendered by the
/// matching JsonFieldHandler, and replaced wholesale on every edit — a
/// handler's onChanged always delivers a NEW state.
abstract class JsonFieldState<SC extends Schema> {
  /// Creates the common part of a field state.
  const JsonFieldState({
    required this.value,
    required this.variants,
    required this.rootSchema,
    this.fieldAnnotations,
    this.matchedVariantIndices = const {},
    this.title,
    this.schema,
    this.errors,
  });

  /// The field's value slice of the document; absent when the document does
  /// not carry this field.
  final PresenceValue<dynamic> value;

  /// Presentation annotations from the resolved schema (description,
  /// examples, required, default, readOnly).
  final FieldAnnotations? fieldAnnotations;

  /// The field label (the schema's `title` or a derived fallback).
  final String? title;

  /// Kept here and used only for determining the best schema via the
  /// closestVariantIndices function. If not for it, the schema would not
  /// be needed here in most cases (Map, List). Try to avoid using this
  /// schema, preferring the State properties instead.
  final SC? schema;

  /// The whole schema document, needed to resolve document-local `$ref`s
  /// reachable from [schema].
  final Schema? rootSchema;

  /// Validation result of this state.
  ///
  /// Contract: null — validation has NOT run for this state; empty list —
  /// validation ran and found nothing; non-empty — validation ran and failed.
  /// [applyErrors] preserves the distinction (an empty result stays an empty
  /// list, it is never collapsed back to null), so "validated clean" is
  /// expressible: gating UI (e.g. dialog OK buttons) must use [isValid], not
  /// a null check. Written through [applyErrors] / [markUnvalidated] (never
  /// via [copyWith], which does not touch it).
  final List<ValidationError>? errors;

  /// The anyOf/oneOf alternatives matched against the value.
  ///
  /// Computed by buildState (empty when nothing matches, several indices on
  /// an equal-score tie) and used by the Variant widget as the INITIAL
  /// dropdown selection only. The live selection is owned by the widget
  /// (its local index plus the isEdited flag): switching does not write this
  /// field back, so after user interaction it goes stale until the state is
  /// rebuilt from the value.
  final Set<int> matchedVariantIndices;

  /// One pre-built state per anyOf/oneOf alternative (or per synthesized
  /// type branch); null when the schema offers no alternatives. See the
  /// staleness contract on [copyWith].
  final List<JsonFieldState<Schema>>? variants;

  /// Staleness contract: a point write (e.g. `copyWith(value:)`) does NOT
  /// refresh derived parts. [variants] entries keep the states built for the
  /// value at buildState time — applyVariantUpdate replaces only the edited
  /// entry, applyVariantSwitched refreshes only the switched-to entry with
  /// the written value — and [matchedVariantIndices] is not recomputed on
  /// value writes. Consumers must treat both as build-time snapshots, not
  /// live views of the current value.
  ///
  /// [errors] is preserved as is; write it through [applyErrors] /
  /// [markUnvalidated]. Subclasses with extra copyable fields override this,
  /// adding their named parameters (ObjectFieldState, RawFieldState).
  JsonFieldState<SC> copyWith({
    PresenceValue<dynamic>? value,
    Set<int>? matchedVariantIndices,
    List<JsonFieldState<Schema>>? variants,
  }) => rebuild(
    value: value ?? this.value,
    matchedVariantIndices: matchedVariantIndices ?? this.matchedVariantIndices,
    variants: variants ?? this.variants,
    errors: errors,
  );

  /// The low-level copy constructor — the ONE method a subclass implements
  /// (a plain constructor call passing the parameters through and carrying
  /// its own extra fields over). Every parameter is required and written
  /// verbatim; there is no null-means-keep convention here — that lives in
  /// [copyWith], and the [errors] semantics live in [applyErrors] /
  /// [markUnvalidated], all implemented on top of this.
  @protected
  JsonFieldState<SC> rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState<Schema>>? variants,
    required List<ValidationError>? errors,
  });

  /// The state of the single matched variant, or null when nothing matched
  /// or the match is unresolvable.
  JsonFieldState<Schema>? get curVariant {
    if (matchedVariantIndices.isEmpty) return null;

    assert(
      matchedVariantIndices.length <= 1,
      'matchedVariantIndices contains several matched variants '
      '($matchedVariantIndices); the first one in insertion order is used. '
      'This usually indicates an ambiguous oneOf/anyOf schema; check '
      'the resolver that fills matchedVariantIndices.',
    );

    final variantsLoc = variants;
    final targetIndex = matchedVariantIndices.first;

    if (variantsLoc == null || targetIndex < 0 || targetIndex >= variantsLoc.length) {
      assert(false, 'matchedVariantIndices points to a non-existent variant: $targetIndex');
      return null;
    }

    return variantsLoc[targetIndex];
  }

  /// Whether the document carries a value for this field (an explicit null
  /// counts as a value).
  bool get hasValue => value.present;

  /// The value, or null when it is absent — indistinguishable from an
  /// explicit null; use [value] where the distinction matters.
  dynamic get valueOrNull => hasValue ? value.valueOrNull : null;

  /// Whether validation has run for this state (see [errors]).
  bool get isValidated => errors != null;

  /// Validated and clean. False both for a failed validation and for a state
  /// that was never validated.
  bool get isValid => errors?.isEmpty ?? false;

  /// Validated and failed.
  bool get hasErrors => errors?.isNotEmpty ?? false;

  /// Stores a validation result, marking the state as validated: an empty
  /// [errors] list is kept as an empty list (validated clean), never
  /// collapsed to null (null means validation has not run, see [errors]).
  JsonFieldState<SC> applyErrors(List<ValidationError> errors) {
    final errorsLoc = this.errors;
    if (errors == errorsLoc) return this;
    // Both "validated clean": keep the identity to avoid useless rebuilds.
    if (errors.isEmpty && errorsLoc != null && errorsLoc.isEmpty) return this;

    return rebuild(value: value, matchedVariantIndices: matchedVariantIndices, variants: variants, errors: errors);
  }

  /// A copy marked as not validated ([errors] = null, see the contract
  /// there); `this` when the state has not been validated already.
  JsonFieldState<SC> markUnvalidated() =>
      errors == null ? this : rebuild(value: value, matchedVariantIndices: matchedVariantIndices, variants: variants, errors: null);

  /// A copy with the value removed from the document (absent, not null).
  JsonFieldState<SC> clear() => copyWith(value: const PresenceValue.absent());

  /// Applies an edit made inside a variant branch: adopts the branch state's
  /// value (falling back to [emptyValue], then to the current value, when
  /// the branch carries none) and stores the updated [actualVariants].
  /// Containers override this to merge instead of replace (see
  /// ObjectFieldState).
  JsonFieldState<SC> resolveVariantUpdate(
    JsonFieldState<Schema> variantState,
    List<JsonFieldState<Schema>> actualVariants,
    PresenceValue<dynamic>? emptyValue,
  ) {
    final newValue = variantState.hasValue ? variantState.value : (emptyValue ?? value);

    return copyWith(
      value: newValue,
      variants: actualVariants,
    );
  }

  /// Returns `this` unchanged if [index] is out of the bounds of
  /// [variants] (the assert fires only in debug). Public callers must
  /// check the bounds themselves beforehand and report the violation via
  /// a platform-appropriate mechanism (see ObjectField._onVariantChanged) —
  /// this method does not guarantee error visibility in production.
  JsonFieldState<SC> applyVariantUpdate(int index, JsonFieldState<Schema> variantState, PresenceValue<dynamic>? emptyValue) {
    final variantsLoc = variants;
    if (variantsLoc == null || index < 0 || index >= variantsLoc.length) {
      assert(false, 'Invalid variant index $index');
      return this;
    }

    final variantsCopy = List<JsonFieldState<Schema>>.of(variantsLoc);
    variantsCopy[index] = variantState;

    return resolveVariantUpdate(variantState, variantsCopy, emptyValue);
  }

  /// The validation messages joined for display, or null when there are none.
  String? get errorsAsString {
    return (errors == null || errors!.isEmpty) ? null : errors!.map((e) => e.toErrorString()).join('\n');
  }
}
