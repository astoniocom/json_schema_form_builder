import 'package:flutter/foundation.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../schema_resolver/schema_merger.dart';
import '../schema_resolver/schema_resolver.dart';
import '../utils/utils.dart';
import 'closest_variant_indices.dart';
import 'cycle_field_state.dart';
import 'field_build_request.dart';
import 'field_context.dart';
import 'json_field_handler.dart';
import 'json_field_state.dart';
import 'json_field_state_builder.dart';
import 'presence_value.dart';
import 'schema_validation_mode.dart';
import 'schema_values.dart';
import 'type_matching.dart';

/// Base registry owning the state building pipeline and validation context
/// creation. Subclasses define only the handler selection policy via
/// [stateBuilderFor], [stateBuilderForValue] and [handlersForSchema].
abstract class JsonHandlerRegistry extends FieldHandlerRegistry<JsonFieldState, FieldDisplayContext, JsonFieldHandler<JsonFieldState>> {
  /// Creates the pipeline part of a registry; subclasses supply the
  /// dispatch tables.
  JsonHandlerRegistry({
    required this.schemaMerger,
    this.validationMode = SchemaValidationMode.strict,
  });

  /// Merges schema fragments (`allOf` branches, `$ref` targets with their
  /// local siblings) during resolution.
  final SchemaMerger schemaMerger;

  /// How values are validated while edited and whether a schema the
  /// validator cannot process blocks submission (see [SchemaValidationMode]).
  /// Consulted by [validateValue] and by the dialogs' submission gates.
  final SchemaValidationMode validationMode;

  /// Fallback handler for values and states no registered handler accepts
  /// (e.g. a free-form JSON text editor). Part of this class (not the
  /// abstract FieldHandlerRegistry contract): the state-building pipeline
  /// needs it to keep [buildStateOrUndefined] and schema-less editing total.
  @protected
  JsonFieldHandler<JsonFieldState> get unknownFieldHandler;

  /// Selection policy: the handlers offered in a "value type" picker (the
  /// entry edit dialog, the array item add dialog) for a field described by
  /// [schema]. When [schema] is null or does not constrain the type, the
  /// user may create a value of any type this registry can edit, so the
  /// implementation returns every pickable handler; the list order defines
  /// the picker order.
  List<JsonFieldHandler<JsonFieldState>> pickableHandlers({
    required FieldResolveContext resolveContext,
    Schema? schema,
  });

  /// Selection policy: the single handler for a field described by [schema]
  /// (already resolved) with the current [value].
  ///
  /// Returns the domain interface: this selection feeds only the
  /// state-building pipeline ([buildState]), which never renders. UI-facing
  /// enumeration goes through [handlersForSchema]/[pickableHandlers], whose
  /// results are also rendered (type names) and therefore stay whole
  /// handlers.
  ///
  /// Implementations must be deterministic functions of their arguments and
  /// must not let an absent [value] influence the choice (an absent value
  /// carries no type information) — otherwise field states are recreated with
  /// a different type on rebuild and user input is lost.
  JsonFieldStateBuilder<JsonFieldState> stateBuilderFor({
    required Schema schema,
    required PresenceValue<dynamic>? value,
    required FieldResolveContext resolveContext,
  });

  /// Selection policy: the handler for a value edited without a schema.
  /// Returns null when no handler can edit the value. Domain interface for
  /// the same reason as [stateBuilderFor].
  JsonFieldStateBuilder<JsonFieldState>? stateBuilderForValue({
    required PresenceValue<dynamic> value,
    required FieldResolveContext resolveContext,
  });

  /// Enumerates all handlers admitted by [schema], based solely on the schema.
  /// Used by the entry edit dialog to offer the "Value type" choice and to
  /// attribute schemas to handlers for validation.
  ///
  /// Contract: returns an EMPTY list when the schema does not constrain the
  /// type. Callers rely on this to fall back to the whole registry
  /// (EntryEditorSnapshot) or to apply the schema to any selected handler
  /// (schemas-to-validate computation). Do not return [unknownFieldHandler]
  /// instead of an empty list.
  List<JsonFieldHandler<JsonFieldState>> handlersForSchema({
    required Schema schema,
    required FieldResolveContext resolveContext,
  });

  /// Resolves $ref/allOf and computes [FieldAnnotations], so the handler
  /// receives an enriched request. A schema carrying a `$ref` also records
  /// the ref in the request's [FieldResolveContext.expandedRefs], so the
  /// contexts derived for children (resolveContext.child) know which targets
  /// the descent has already expanded — the bookkeeping behind the cycle
  /// guard in [buildState].
  Future<FieldBuildRequest> _enrichRequest(FieldBuildRequest request) async {
    var schemaSource = request.schemaSource;
    var resolveContext = request.resolveContext;

    if (schemaSource != null) {
      final rawRef = schemaSource.schema.value[r'$ref'];
      if (rawRef is String) resolveContext = resolveContext.withExpandedRef(rawRef);

      final (resolvedSchema, newContext) = await resolveSchema(
        schemaSource.schema,
        request.value.valueOrNull,
        request.resolveContext.path,
        schemaSource.validationContext,
        schemaMerger,
      );
      schemaSource = SchemaWithContext(schema: resolvedSchema, validationContext: newContext);
    }
    final resolvedSchema = schemaSource?.schema;

    final fieldAnnotations = FieldAnnotations(
      description: resolvedSchema?.description,
      examples: resolvedSchema?.examples,
      required: request.required,
      defaultValue: (resolvedSchema?.value.containsKey('default') ?? false) ? PresenceValue(resolvedSchema?.defaultValue) : const PresenceValue.absent(),
      // A const-pinned field admits exactly one value, so it is never
      // directly editable; the value is written by the surrounding logic
      // (e.g. switching an anyOf/oneOf alternative).
      //
      // Deliberately schemaHasConst, NOT schemaPinnedValue (which also
      // covers a single-element enum): a one-option dropdown must stay
      // interactable — picking the option is the user's only way to turn
      // the field present (schemaSeedValue seeds const, not enums), and a
      // single-element enum says "choose from this list" (which may grow),
      // not "the author fixed this value".
      readOnly: request.readOnly || (resolvedSchema?.readOnly ?? false) || schemaHasConst(resolvedSchema),
    );

    return request.copyWith(
      schemaSource: schemaSource,
      resolveContext: resolveContext,
      fieldAnnotations: fieldAnnotations,
    );
  }

  /// The cycle guard: a field whose raw schema `$ref` repeats a target
  /// already expanded on this descent ([FieldResolveContext.expandedRefs])
  /// is not expanded — the descent `node -> next -> node -> …` would
  /// otherwise never terminate. The field is represented by a
  /// [CycleFieldState] instead (see CycleFieldHandler).
  ///
  /// The guard fires regardless of the value — deliberately: hosts rebuild
  /// the state tree from the value on every change, and if the guard
  /// depended on the value, the widget at the repeat position would flip
  /// between the collapsed field and the real editor on the first keystroke,
  /// recreating the element subtree and killing focus. Instead the widget
  /// (CycleField) stays at this position permanently: valueless it renders
  /// an "Expand cycle" button, with a value it builds and shows the real
  /// subtree itself (recursion stays bounded — data is finite). The value is
  /// passed through into the state, so Json -> State -> Json identity holds.
  CycleFieldState? _guardedCycleState(FieldBuildRequest request) {
    final rawSchema = request.schemaSource?.schema;
    final rawRef = rawSchema?.value[r'$ref'];
    if (rawRef is! String) return null;
    if (!request.resolveContext.expandedRefs.contains(rawRef)) return null;

    return CycleFieldState(
      value: request.value,
      rootSchema: request.resolveContext.rootSchema,
      expandedRefs: request.resolveContext.expandedRefs,
      schema: rawSchema,
      title: request.title,
      fieldAnnotations: FieldAnnotations(required: request.required, readOnly: request.readOnly),
      errors: request.errors,
    );
  }

  /// The anyOf/oneOf variant engine: the last enrichment step before
  /// dispatching to the handler. Builds the alternatives' states
  /// (recursively through [buildState]) and matches the current value
  /// against them, so the handler receives
  /// [FieldBuildRequest.variants]/[FieldBuildRequest.matchedVariantIndices]
  /// pre-computed.
  ///
  /// A union type list (type: ["string", "integer"]) without own
  /// alternatives gets synthesized single-type branches, so the same Variant
  /// switcher lets the user pick which type to enter. An explicit
  /// anyOf/oneOf wins: its alternatives constrain the union further, and
  /// synthesizing on top of them would double the switcher.
  ///
  /// Must run after schema resolution ([_enrichRequest]) and on the final
  /// (possibly seeded) value: both the alternatives and the matching depend
  /// on them.
  Future<FieldBuildRequest> _withVariants(FieldBuildRequest request) async {
    final schema = request.schema;
    if (schema == null) return request;

    var variantSchema = schema.anyOf ?? schema.oneOf; // anyOf takes priority over oneOf
    variantSchema ??= synthesizedTypeBranchSchemas(schema);
    if (variantSchema == null) return request;

    final variants = await _buildStatesList(schemaList: variantSchema, request: request);
    if (variants == null) return request;

    Set<int> matchedVariantIndices = {};
    if (variants.isNotEmpty) {
      matchedVariantIndices = await closestVariantIndices(
        options: variants.map((sf) => sf.schema).toList(growable: false),
        // See normalizeJsonValue: literal-built maps crash the validator.
        formData: normalizeJsonValue(request.value.valueOrNull),
        validator: (schema, value) async {
          try {
            // The build-time resolve context lets `$ref`s pointing into the
            // root document resolve; a plain schema.validate registers only
            // the alternative itself. schemaSource is non-null here: the
            // alternatives came from request.schema. Draft-07 tuple syntax
            // is normalized away first (see normalizeDraft07Tuples).
            final normalizedOption = normalizeDraft07Tuples(schema);
            final result = await normalizedOption.validateSchema(value, [], request.schemaSource!.validationContext, [normalizedOption]);
            return result.errors.isEmpty;
          } catch (_) {
            // A schema the validator cannot process counts as non-matching.
            return false;
          }
        },
      );
    }

    return request.copyWith(variants: variants, matchedVariantIndices: matchedVariantIndices);
  }

  Future<List<JsonFieldState>?> _buildStatesList({
    required List<Object?>? schemaList,
    required FieldBuildRequest request,
  }) async {
    if (schemaList == null) return null;
    final List<JsonFieldState> result = [];
    final readOnly = request.fieldAnnotations?.readOnly ?? false;

    for (final sc in schemaList) {
      if (sc is! Schema) continue;
      // A fresh request (not copyWith): the alternative state must get the
      // alternative's own title (possibly null), not inherit the parent's,
      // and must not inherit the parent's fieldAnnotations.
      final childState = await buildState(
        FieldBuildRequest(
          value: request.value,
          // A variant shows only field-level errors; general errors must be shown
          // by the widget above so that errors are not duplicated.
          errors: request.errors?.where((e) => e.path.isNotEmpty).toList(growable: false),
          resolveContext: request.resolveContext,
          title: sc.title,
          // schemaSource is non-null here: the schemaList came from
          // request.schema (anyOf/oneOf).
          schemaSource: SchemaWithContext(schema: sc, validationContext: request.schemaSource!.validationContext),
          readOnly: readOnly || (sc.readOnly ?? false),
        ),
      );
      if (childState == null) continue;
      result.add(childState);
    }

    return result;
  }

  /// The entry point of state building: enriches [request] (schema
  /// resolution, annotations, seeding, variants), selects a state builder by
  /// schema or value, and builds the state. Null when there is neither a
  /// schema nor a value to build from. A repeated `$ref` without a value is
  /// collapsed into a CycleFieldState instead of recursing.
  ///
  /// Deliberately asynchronous — a settled API decision for 0.x, not an
  /// accident: schema resolution may need the validator's ValidationContext,
  /// whose `$ref` retrieval is async by contract (a dialect-legal remote
  /// ref), and handler buildState overrides inherit that. Making the
  /// pipeline synchronous would first require a document-local resolver
  /// contract; worth revisiting only after 1.0.
  Future<JsonFieldState?> buildState(FieldBuildRequest request) async {
    final guarded = _guardedCycleState(request);
    if (guarded != null) return guarded;

    final enriched = await _enrichRequest(request);
    final schema = enriched.schema;

    JsonFieldStateBuilder<JsonFieldState>? stateBuilder;
    if (schema != null) {
      stateBuilder = stateBuilderFor(schema: schema, value: enriched.value, resolveContext: enriched.resolveContext);
    } else if (enriched.value.present) {
      stateBuilder = stateBuilderForValue(value: enriched.value, resolveContext: enriched.resolveContext) ?? unknownFieldHandler;
    }

    if (stateBuilder == null) return null; // schema is null and values is not presented

    return stateBuilder.buildState(await _withVariants(enriched));
  }

  /// Builds the initial state for a field that extends the JSON document on
  /// user interaction: a new object property or a new array item.
  ///
  /// Seeds the request with the value the
  /// schema prescribes ([schemaSeedValue]: `const`, then `default`, then --
  /// for objects -- property defaults collected recursively) when [request]
  /// carries no meaningful value (absent or null) and the seed's type is
  /// editable by the handler. `const` takes precedence: a const-pinned field
  /// is read-only, so unless its value is written here it would stay null
  /// forever. Building state from existing JSON must never do this
  /// (Json -> State -> Json is an identity), which is why seeds are applied
  /// only at extension points.
  ///
  /// When [stateBuilder] is null it is selected from the RESOLVED schema via
  /// [stateBuilderFor]. Callers use this when the raw schema admits no handler
  /// before resolution (e.g. a bare `$ref`).
  Future<JsonFieldState> buildStateForNewField({
    required FieldBuildRequest request,
    JsonFieldStateBuilder<JsonFieldState>? stateBuilder,
  }) async {
    // The const/default lives in the resolved schema, so a first enrichment
    // pass is needed just to discover it. When the seed is applied, the
    // request is re-enriched from scratch: schema resolution is
    // value-dependent, and the resolved-for-no-value schema must not leak
    // into the built state.
    final enriched = await _enrichRequest(request);

    final effectiveHandler =
        stateBuilder ??
        (enriched.schema != null
            ? stateBuilderFor(schema: enriched.schema!, value: enriched.value, resolveContext: enriched.resolveContext)
            : unknownFieldHandler);

    final PresenceValue<Object?> seedValue = schemaSeedValue(enriched.schema, rootSchema: enriched.resolveContext.rootSchema);
    final hasMeaningfulValue = enriched.value.present && enriched.value.valueOrNull != null;

    if (!seedValue.present || hasMeaningfulValue) return effectiveHandler.buildState(await _withVariants(enriched));

    final rawSeed = seedValue.valueOrNull;
    final isSupported = rawSeed == null || effectiveHandler.canEditValue(rawSeed);
    if (!isSupported) return effectiveHandler.buildState(await _withVariants(enriched));

    // The variant step runs on the re-enriched request: alternatives and
    // their matching depend on the seeded value.
    return effectiveHandler.buildState(await _withVariants(await _enrichRequest(request.copyWith(value: PresenceValue(rawSeed)))));
  }

  /// [buildState], but total: falls back to the unknown-field handler
  /// instead of returning null.
  Future<JsonFieldState> buildStateOrUndefined(FieldBuildRequest request) async {
    final result = await buildState(request);

    return result ?? await unknownFieldHandler.buildState(request);
  }

  /// Runs [body] with a ValidationContext for [itemSchema] and disposes the
  /// backing SchemaRegistry afterwards, even when [body] throws.
  ///
  /// The context passed to [body] is null only when [itemSchema] is null
  /// (callers usually have an optional schema).
  Future<T> withValidationContext<T>({
    required Schema? itemSchema,
    required Schema? rootSchema,
    required Future<T> Function(ValidationContext? validationContext) body,
  }) async {
    if (itemSchema == null) return body(null);

    final (validationContext, schemaRegistry) = buildStandaloneValidationContext(itemSchema: itemSchema, rootSchema: rootSchema);
    try {
      return await body(validationContext);
    } finally {
      schemaRegistry.dispose();
    }
  }

  /// Validates [value] against [itemSchema] with a ValidationContext whose
  /// registry holds [rootSchema], so `$ref`s pointing into the root document
  /// (e.g. `#/definitions/...`) resolve. A plain `schema.validate(value)`
  /// registers only the item schema itself and cannot resolve such refs.
  ///
  /// A schema the validator cannot process surfaces as a visible error
  /// instead of crashing the caller (same policy as validateDataBySchema).
  ///
  /// Under [SchemaValidationMode.none] validation is skipped entirely and
  /// the result is empty ("validated clean"), so editing flows are never
  /// blocked by validation.
  Future<List<ValidationError>> validateValue({
    required Schema? itemSchema,
    required Schema? rootSchema,
    required dynamic value,
  }) async {
    if (itemSchema == null || validationMode == SchemaValidationMode.none) return const [];

    return withValidationContext(
      itemSchema: itemSchema,
      rootSchema: rootSchema,
      body: (validationContext) async {
        try {
          // See normalizeJsonValue (literal-built maps crash the validator)
          // and normalizeDraft07Tuples (list-valued `items` does too).
          final normalizedSchema = normalizeDraft07Tuples(itemSchema);
          final result = await normalizedSchema.validateSchema(normalizeJsonValue(value), [], validationContext!, [normalizedSchema]);
          return result.errors;
        } catch (e) {
          return validatorRejectedSchemaErrors(e);
        }
      },
    );
  }
}
