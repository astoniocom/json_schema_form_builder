import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_build_request.dart';
import '../../models/field_context.dart';
import '../../models/json_field_handler.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registration.dart';
import '../../models/json_handler_registry.dart';
import '../../models/presence_value.dart';
import '../../models/type_matching.dart';
import '../../schema_resolver/schema_resolver.dart';
import '../../utils/utils.dart';
import '../../widgets/field_with_variants.dart';
import 'array_field.dart';
import 'array_field_state.dart';

/// The handler of array fields: builds ArrayFieldState (one child state per
/// element, tuple and enum multi-select detection) and renders an ArrayField.
class ArrayFieldHandler extends JsonFieldHandler<ArrayFieldState> {
  /// Creates the handler; see the fields for the knobs.
  const ArrayFieldHandler({
    required super.registryGetter,
    this.inline = false,
    this.validateOnChange = true,
    this.minInlineWidth = defaultMinInlineWidth,
    // An array emptied by user edits stays in the document as [] (rjsf-like)
    // instead of collapsing to absent, which would drop the property's key
    // from the parent (and the whole document at the form root). Configure
    // PresenceValue.absent() to get the collapsing behavior.
    this.emptyValue = const PresenceValue(<Object?>[]),
  });

  /// Whether the array renders its rows in place when the width allows;
  /// false always renders the collapsed row opening the edit dialog.
  final bool inline;

  /// Whether edits inside the editor dialog are validated as they happen.
  final bool validateOnChange;

  /// Minimal width (logical px) at which an [inline] editor is still usable;
  /// in a narrower slot the field collapses into a compact editor (a button
  /// that opens the edit dialog) instead.
  final double minInlineWidth;

  /// What an array emptied by user edits writes: `[]` by default (rjsf-like,
  /// keeps the key in the parent), `PresenceValue.absent()` to collapse.
  final PresenceValue<dynamic> emptyValue;

  @override
  PresenceValue<dynamic>? variantEmptyValue(ArrayFieldState fieldState) => emptyValue;

  @override
  Widget buildField({
    required BuildContext context,
    required ArrayFieldState fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  }) {
    // Any variants — declared anyOf/oneOf or synthesized type branches —
    // render only the switcher, as for scalars. Unlike objects (where the
    // base editor and a branch split the children by property name, see
    // ObjectFieldHandler.buildField), an array branch state is built from
    // the branch schema alone and renders EVERY element, so a base list
    // editor alongside the switcher would duplicate the rows. Consistently,
    // ArrayFieldState has no merge override: a branch write replaces the
    // value wholesale.
    if (fieldState.variants?.isNotEmpty ?? false) {
      return buildFieldWithVariants(
        context: context,
        fieldState: fieldState,
        displayContext: displayContext,
        onChanged: onChanged,
        // Unreachable: buildFieldWithVariants only consults the content
        // builder when there are no variants.
        contentBuilder: (_) => const SizedBox.shrink(),
      );
    }

    return ArrayField(
      fieldState: fieldState,
      emptyValue: emptyValue,
      registry: registry,
      inline: inline,
      minInlineWidth: minInlineWidth,
      displayContext: displayContext,
      onChanged: onChanged,
      validateOnChange: validateOnChange,
      child: buildVariant(context: context, fieldState: fieldState, displayContext: displayContext, onChanged: onChanged),
    );
  }

  Future<(Schema?, ValidationContext?)> _getSchemaForItem({
    required List<Schema> unresolvedPositionalItemSchemas,
    required Schema? unresolvedAdditionalItemsSchema,
    required int index,
    required ValidationContext? validationContext,
    required dynamic itemValue,
    required FieldResolveContext resolveContext,
  }) async {
    Schema? rawItemSchema;
    ValidationContext? newContext = validationContext;
    if (unresolvedPositionalItemSchemas.isNotEmpty && index < unresolvedPositionalItemSchemas.length) {
      rawItemSchema = unresolvedPositionalItemSchemas[index];
    } else if (unresolvedAdditionalItemsSchema != null) {
      rawItemSchema = unresolvedAdditionalItemsSchema;
    }

    if (newContext != null && rawItemSchema != null) {
      (rawItemSchema, newContext) = await resolveSchema(
        rawItemSchema,
        itemValue,
        resolveContext.child(index.toString()).path,
        newContext,
        registry.schemaMerger,
      );
    }
    return (rawItemSchema, newContext);
  }

  Future<(List<JsonListFieldEntry>, ValidationContext?)> _resolveChildren({
    required List<Schema> unresolvedPositionalItemSchemas,
    required Schema? unresolvedAdditionalItemsSchema,
    required ValidationContext? validationContext,
    required FieldResolveContext resolveContext,
    required bool readOnly,
    required List<ValidationError>? errors,
    required dynamic rawValue,
  }) async {
    final List<JsonListFieldEntry> children = [];
    ValidationContext? newValidationContext = validationContext;

    for (final (index, itemValue) in (rawValue is List<dynamic> ? rawValue : []).indexed) {
      final (itemSchema, resolvedContext) = await _getSchemaForItem(
        unresolvedPositionalItemSchemas: unresolvedPositionalItemSchemas,
        unresolvedAdditionalItemsSchema: unresolvedAdditionalItemsSchema,
        index: index,
        validationContext: newValidationContext,
        itemValue: itemValue,
        resolveContext: resolveContext,
      );
      newValidationContext = resolvedContext;

      final errorsForItem = errors
          ?.where((e) => e.path.firstOrNull == index.toString())
          .map((e) => ValidationError(e.error, path: e.path.sublist(1), details: e.details))
          .toList(growable: false);
      final entryState = await registry.buildStateOrUndefined(
        FieldBuildRequest(
          value: PresenceValue(itemValue),
          // itemSchema derives from the list schema, whose request always
          // carries a context, so `maybe` never sees a context-less schema.
          schemaSource: SchemaWithContext.maybe(itemSchema, newValidationContext),
          errors: errorsForItem,
          title: itemSchema?.title,
          resolveContext: resolveContext.child(index.toString()),
          readOnly: readOnly,
        ),
      );

      final newEntry = JsonListFieldEntry(state: entryState, additional: true);
      children.add(newEntry);
    }

    return (children, newValidationContext);
  }

  static Schema? _parseSchema(dynamic raw) {
    if (raw is Schema) return raw;
    if (raw is Map<String, Object?>) return Schema.fromMap(raw);
    if (raw is Map) return Schema.fromMap(Map<String, Object?>.from(raw));
    return null;
  }

  /// Extracts the tuple (positional) schemas and the additional-items schema
  /// from both dialects:
  ///
  /// - 2020-12: `prefixItems: [...]` holds the positional schemas and
  ///   `items` (a single schema) constrains the elements beyond them.
  /// - draft-07: `items: [...]` holds the positional schemas and
  ///   `additionalItems` the rest. Rendered natively here; for validation
  ///   the entry points rewrite this form into the 2020-12 spelling first
  ///   (see normalizeDraft07Tuples), so both dialects validate.
  (List<Schema>, Schema?) _extractItemSchemasToResolve(ListSchema listSchema) {
    final List<Schema> rawItemSchemas = [];

    final prefixItems = listSchema.value['prefixItems'];
    final listSchemaItems = listSchema.value['items'];

    final positionalList = prefixItems is List ? prefixItems : (listSchemaItems is List ? listSchemaItems : null);
    if (positionalList != null) {
      rawItemSchemas.addAll(
        positionalList.map((rawSchema) {
          final schema = _parseSchema(rawSchema);
          if (schema != null) {
            return schema;
          } else {
            // Cannot skip it, because we must preserve the ability
            // to match index against children.index.
            assert(false, 'Positional item entries must be schema Maps.');
            return Schema.any();
          }
        }),
      );
    }

    // The additional-items schema: a non-List `items` covers both the plain
    // homogeneous array and the 2020-12 "beyond prefixItems" role;
    // `additionalItems` is the draft-07 fallback.
    Schema? rawAdditionalItemSchema;
    if (listSchemaItems is! List) {
      rawAdditionalItemSchema = _parseSchema(listSchemaItems);
    }
    rawAdditionalItemSchema ??= _parseSchema(listSchema.value['additionalItems']);

    return (rawItemSchemas, rawAdditionalItemSchema);
  }

  Future<(List<Schema>, Schema?)> _resolveItemSchemasForNew({
    required List<Schema> unresolvedPositionalItemSchemas,
    required Schema? unresolvedAdditionalItemsSchema,
    required ValidationContext? validationContext,
    required FieldResolveContext resolveContext,
    required int childrenLength,
  }) async {
    final List<Schema> resolvedPositionSchemas = [];
    Schema? resolvedAdditionalSchema = unresolvedAdditionalItemsSchema;

    if (validationContext != null) {
      var contextLoc = validationContext;
      for (final (index, itemSchema) in unresolvedPositionalItemSchemas.indexed) {
        final (resolved, nextCtx) = await resolveSchema(
          itemSchema,
          itemSchema.defaultValue,
          resolveContext.child(index.toString()).path,
          contextLoc,
          registry.schemaMerger,
        );
        contextLoc = nextCtx;
        resolvedPositionSchemas.add(resolved);
      }

      if (unresolvedAdditionalItemsSchema != null) {
        final (resolved, _) = await resolveSchema(
          unresolvedAdditionalItemsSchema,
          unresolvedAdditionalItemsSchema.defaultValue,
          resolveContext.child(childrenLength.toString()).path,
          contextLoc,
          registry.schemaMerger,
        );
        resolvedAdditionalSchema = resolved;
      }
    } else {
      resolvedPositionSchemas.addAll(unresolvedPositionalItemSchemas);
    }

    return (resolvedPositionSchemas, resolvedAdditionalSchema);
  }

  @override
  Future<ArrayFieldState> buildState(FieldBuildRequest request) async {
    final schema = request.schema;
    final value = request.value;
    final errors = request.errors;
    final resolveContext = request.resolveContext;

    final ListSchema? listSchema = schema is ListSchema ? schema : null;

    final (unresolvedPositionalItemSchemas, unresolvedAdditionalItemsSchema) = listSchema != null
        ? _extractItemSchemasToResolve(listSchema)
        : (<Schema>[], null);

    final (children, updatedValidationContext) = await _resolveChildren(
      unresolvedPositionalItemSchemas: unresolvedPositionalItemSchemas,
      unresolvedAdditionalItemsSchema: unresolvedAdditionalItemsSchema,
      validationContext: request.schemaResolveContext,
      resolveContext: resolveContext,
      readOnly: request.fieldAnnotations?.readOnly ?? false,
      errors: errors,
      rawValue: value.valueOrNull,
    );

    // Building state from JSON must not modify the input (Json -> State ->
    // Json is an identity): an absent value stays absent, an explicit empty
    // list is kept as [], a type-mismatched (non-list) value is kept as is.
    // defaultValue/emptyValue are applied only on user interaction.

    final (positionalItemSchemasForNew, additionalItemsSchemaForNew) = await _resolveItemSchemasForNew(
      unresolvedPositionalItemSchemas: unresolvedPositionalItemSchemas,
      unresolvedAdditionalItemsSchema: unresolvedAdditionalItemsSchema,
      validationContext: updatedValidationContext,
      resolveContext: resolveContext,
      childrenLength: children.length,
    );

    return ArrayFieldState(
      schema: schema is ListSchema ? schema : null,
      rootSchema: resolveContext.rootSchema,
      value: value,
      children: children,
      errors: errors?.where((e) => e.path.isEmpty).toList(growable: false),
      title: request.title,
      fieldAnnotations: request.fieldAnnotations,
      variants: request.variants,
      matchedVariantIndices: request.matchedVariantIndices,
      uniqueItems: listSchema?.uniqueItems ?? false,
      positionalItemSchemasForNew: positionalItemSchemasForNew,
      additionalItemsSchemaForNew: additionalItemsSchemaForNew,
    );
  }

  /// The default wiring of this handler for a type-based registry: claims
  /// the `array` schema type and the List value type.
  static JsonHandlerRegistration registration(JsonHandlerRegistry Function() registryGetter, {bool inline = false}) => JsonHandlerRegistration(
    stateType: ArrayFieldState,
    handler: ArrayFieldHandler(registryGetter: registryGetter, inline: inline),
    valueTypes: const [List<dynamic>],
    schemaTypes: const [JsonType.list],
  );

  @override
  bool canEditValue(dynamic value) => dartTypeOfValue(value) == List<dynamic>;

  @override
  PresenceValue<dynamic>? get canonicalEmptyValue => const PresenceValue(<Object?>[]);

  @override
  String typeDisplayName(BuildContext context) => jsonFormLocalizationsOf(context).typeNameArray;

  @override
  bool matchesState(JsonFieldState state) {
    return state is ArrayFieldState;
  }
}
