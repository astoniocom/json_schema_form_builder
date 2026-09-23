import 'package:json_schema_builder/json_schema_builder.dart';

import '../../../json_schema_form_builder.dart';

/// One element of an [ArrayFieldState]: the element's state plus whether it
/// sits beyond the positional (tuple) schemas.
class JsonListFieldEntry {
  /// Creates an entry around [state].
  const JsonListFieldEntry({
    required this.state,
    required this.additional,
  });

  /// The element's field state.
  final JsonFieldState state;

  /// True when the element is governed by the additional-items schema
  /// (2020-12 `items` next to `prefixItems`, draft-07 `additionalItems`)
  /// rather than by a positional one.
  final bool additional;

  /// Whether the element failed validation.
  bool get hasErrors => state.hasErrors;
}

/// The state of an array field: the element states, the schemas for
/// appending new elements, and the enum multi-select detection.
class ArrayFieldState extends JsonFieldState<ListSchema> {
  /// Creates an array field state.
  const ArrayFieldState({
    required super.value,
    required this.children,
    required super.variants,
    required super.rootSchema,
    super.matchedVariantIndices,
    super.title,
    super.fieldAnnotations,
    super.schema,
    this.positionalItemSchemasForNew = const [],
    this.additionalItemsSchemaForNew,
    this.uniqueItems = false,
    super.errors,
  });

  /// The element states, in document order.
  final List<JsonListFieldEntry> children;

  /// The schema's `uniqueItems`; with a select-like items schema it turns
  /// the editor into an enum multi-select (see [isEnum]).
  final bool uniqueItems;

  /// Resolved positional (tuple) schemas: the next new element takes the
  /// first still-unfilled one.
  final List<Schema> positionalItemSchemasForNew;

  /// Resolved schema for elements beyond the positional ones; null when the
  /// tuple is closed or `items` is unconstrained.
  final Schema? additionalItemsSchemaForNew;

  /// Whether any element failed validation (surfaced on the collapsed
  /// representation, where element errors are invisible).
  bool get childrenHasErrors => children.any((c) => c.hasErrors);

  /// See the staleness contract on [JsonFieldState.copyWith]; [children]
  /// follows the same rule (a build-time snapshot, not refreshed by point
  /// writes).
  @override
  ArrayFieldState copyWith({
    Set<int>? matchedVariantIndices,
    PresenceValue<dynamic>? value,
    List<JsonFieldState>? variants,
    List<JsonListFieldEntry>? children,
  }) {
    return ArrayFieldState(
      value: value ?? this.value,
      children: children ?? this.children,
      variants: variants ?? this.variants,
      matchedVariantIndices: matchedVariantIndices ?? this.matchedVariantIndices,
      title: title,
      fieldAnnotations: fieldAnnotations,
      schema: schema,
      errors: errors,
      positionalItemSchemasForNew: positionalItemSchemasForNew,
      additionalItemsSchemaForNew: additionalItemsSchemaForNew,
      uniqueItems: uniqueItems,
      rootSchema: rootSchema,
    );
  }

  @override
  ArrayFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return ArrayFieldState(
      value: value,
      children: children,
      variants: variants,
      matchedVariantIndices: matchedVariantIndices,
      title: title,
      fieldAnnotations: fieldAnnotations,
      schema: schema,
      errors: errors,
      positionalItemSchemasForNew: positionalItemSchemasForNew,
      additionalItemsSchemaForNew: additionalItemsSchemaForNew,
      uniqueItems: uniqueItems,
      rootSchema: rootSchema,
    );
  }

  /// Distributes [errors] by path: element errors go into the matching
  /// child states, the rest (including unassignable paths) stay on the
  /// array itself.
  @override
  ArrayFieldState applyErrors(List<ValidationError> errors) {
    final List<JsonListFieldEntry> resultChildren = [];

    for (final (index, child) in children.indexed) {
      final indexStr = index.toString();

      final errorsForField = errors
          .where((e) => e.path.firstOrNull == indexStr)
          .map((e) => ValidationError(e.error, path: e.path.sublist(1), details: e.details))
          .toList(growable: false);

      resultChildren.add(
        JsonListFieldEntry(
          additional: child.additional,
          state: child.state.applyErrors(errorsForField),
        ),
      );
    }

    // Extract the errors for the current field; errors not assigned to
    // child fields also end up here so they are not lost.
    final fieldErrors = errors
        .where((e) {
          if (e.path.isEmpty) return true;
          final firstIndex = int.tryParse(e.path.first);
          return firstIndex == null || firstIndex < 0 || firstIndex >= children.length;
        })
        .toList(growable: false);
    // Even an empty fieldErrors list is kept: validation ran, the state is
    // "validated clean" (see JsonFieldState.errors).
    return ArrayFieldState(
      value: value,
      children: resultChildren,
      variants: variants,
      matchedVariantIndices: matchedVariantIndices,
      title: title,
      fieldAnnotations: fieldAnnotations,
      schema: schema,
      errors: fieldErrors,
      positionalItemSchemasForNew: positionalItemSchemasForNew,
      additionalItemsSchemaForNew: additionalItemsSchemaForNew,
      uniqueItems: uniqueItems,
      rootSchema: rootSchema,
    );
  }

  /// The items schema the multi-select works with: the one resolved against
  /// the validation context when available ([additionalItemsSchemaForNew]),
  /// so an `items` given as a `$ref` is seen through; the raw `items` schema
  /// otherwise. Null for a tuple (positional `prefixItems`, or the draft-07
  /// form of a List-valued `items`).
  Schema? get itemsSchemaForEnum {
    // `items` is read raw first: when it is a List (draft-07 tuple, a form
    // json_schema_builder does not support), accessing schema?.items would
    // throw a cast error (type 'List<...>' is not a subtype of
    // type 'Map<String, Object?>').
    final rawItems = schema?.value['items'];
    if (rawItems is List || schema?.value['prefixItems'] is List) return null;
    return additionalItemsSchemaForNew ?? schema?.items;
  }

  /// Options of the enum multi-select; null when the items schema is not
  /// select-like ([schemaEnumOptions]).
  List<EnumOption>? get enumOptions => schemaEnumOptions(itemsSchemaForEnum);

  /// Whether the array renders as an enum multi-select (EnumArrayField):
  /// unique items whose `items` schema is select-like -- a plain `enum` or
  /// anyOf/oneOf of pinned alternatives. Mirrors react-jsonschema-form's
  /// isMultiSelect.
  bool get isEnum => uniqueItems && enumOptions != null;
}
