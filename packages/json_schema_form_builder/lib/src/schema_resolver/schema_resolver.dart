/// The resolution boundary between this package and json_schema_builder.
///
/// json_schema_builder validates values and looks up `$ref` targets
/// (Schema.resolveRef), but exposes no API that produces the *effective*
/// schema of a field -- the flattened view a form needs to decide which
/// editor to show, which properties exist and what is required. That gap is
/// what this file (plus SchemaMerger) fills, and nothing more.
///
/// Delegated to the library:
///  - all validation (validateSchema), including anyOf/oneOf/not semantics;
///  - `$ref` target lookup (Schema.resolveRef), including $id-relative URIs;
///  - the schema object model (Schema and its typed subclasses).
///
/// Resolved here, applied to each field's schema before a handler sees it:
///  - `$ref`: the target is resolved recursively, then merged with the local
///    siblings (a local keyword overrides the referenced one);
///  - `allOf`: every branch is fully resolved, then flattened via
///    SchemaMerger;
///  - `if`/`then`/`else`: the matching branch is merged in and the
///    conditional keys are stripped. Deliberate rjsf deviation from the
///    spec: when none of the `if` properties is present in the data, the
///    condition is treated as not firing (per spec an empty object would
///    satisfy a requirement-free `if` and pull `then` in);
///  - `dependencies` (draft-07): normalized into dependentRequired /
///    dependentSchemas;
///  - `dependentRequired` / `dependentSchemas`: applied only for keys
///    present in the data.
///
/// Deliberately not resolved anywhere (validation still enforces them, the
/// form just does not specialize its editors): `anyOf`/`oneOf` (surfaced as
/// variant alternatives instead of being merged), `not`, `contains`,
/// `propertyNames`, `unevaluated*`.
///
/// Known limitations, each pinned by a test in the 'schema resolution
/// boundary' group:
///  - schemaSeedValue (schema_values.dart) expands document-local `$ref`s
///    (`#/...`) and `allOf` inside property schemas on its own (sync,
///    without this resolver), but does not follow non-local refs (remote
///    URLs, `$id`-relative, `$anchor`) — `default`s behind those are not
///    picked up at document extension points;
///  - meta-schemas (`$schema`) are stubbed locally (see
///    JsonHandlerRegistry) because the library fetches them over the
///    network, which fails offline and on the web.
library;

import 'package:flutter/material.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../utils/utils.dart';
import 'schema_merger.dart';

/// Resolves [schema] for [data] at [currentPath]: follows document-local
/// `$ref`s, merges `allOf`, applies the matching `if`/`then`/`else` branch
/// and `dependencies`/`dependentSchemas`/`dependentRequired` (see the
/// library docs above for what is deliberately left to the validator).
/// Returns the resolved schema with the context it must be validated in.
Future<(Schema, ValidationContext)> resolveSchema(
  Schema schema,
  Object? data,
  List<String> currentPath,
  ValidationContext context,
  SchemaMerger schemaMerger,
) async {
  var (currentSchema, currentContext) = (schema, context);

  currentSchema = _normalizeDependencies(currentSchema);

  (currentSchema, currentContext) = await _resolveRef(
    currentSchema,
    data,
    currentPath,
    currentContext,
    schemaMerger,
  );

  (currentSchema, currentContext) = await _resolveAllOf(
    currentSchema,
    data,
    currentPath,
    currentContext,
    schemaMerger,
  );

  (currentSchema, currentContext) = await _resolveIfThenElse(
    currentSchema,
    data,
    currentPath,
    currentContext,
    schemaMerger,
  );

  (currentSchema, currentContext) = await _resolveDependentRequired(
    currentSchema,
    data,
    currentPath,
    currentContext,
  );

  (currentSchema, currentContext) = await _resolveDependentSchemas(
    currentSchema,
    data,
    currentPath,
    currentContext,
    schemaMerger,
  );

  return (currentSchema, currentContext);
}

// ---------------------------------------------------------------------------
// Step 1 — $ref
//
// The referenced schema is resolved recursively before merging so that
// chains like $ref → $ref or $ref → allOf are fully expanded.
// Merge is done via _schemaMerger so type intersections, recursive
// properties, etc. are handled correctly.
// $ref is stripped from the local schema before merge to prevent re-entry.
// ---------------------------------------------------------------------------

Future<(Schema, ValidationContext)> _resolveRef(
  Schema schema,
  Object? data,
  List<String> currentPath,
  ValidationContext context,
  SchemaMerger schemaMerger,
) async {
  final ref = schema.$ref;
  if (ref == null) return (schema, context);

  final resolution = await schema.resolveRef(ref, context.rootSchema, context);

  if (resolution == null) {
    debugPrint('Cannot resolve \$ref: "$ref"');
    return (schema, context);
  }

  final (referencedSchema, referencedUri) = resolution;
  // json_schema_builder 0.1.7 made ValidationContext.withSourceUri private,
  // so the context is rebuilt through the public constructor with the same
  // public state. The only thing not carried over is the context's private
  // record of failed remote fetches (a failed fetch may be retried under the
  // new source URI) — harmless here: form building pre-registers the root
  // document and meta-schema stubs in the registry and performs no remote
  // fetches.
  var currentContext = ValidationContext(
    context.rootSchema,
    strictFormat: context.strictFormat,
    sourceUri: referencedUri,
    schemaRegistry: context.schemaRegistry,
    vocabularies: context.vocabularies,
    loggingContext: context.loggingContext,
  );

  final (resolvedRef, resolvedRefContext) = await resolveSchema(
    referencedSchema,
    data,
    currentPath,
    currentContext,
    schemaMerger,
  );

  currentContext = resolvedRefContext;

  final localWithoutRef = Map<String, dynamic>.of(schema.value)..remove(r'$ref');

  final merged = schemaMerger.mergeSchemas(resolvedRef.value, localWithoutRef);

  return (Schema.fromMap(merged), currentContext);
}

// ---------------------------------------------------------------------------
// Step 2 — allOf
//
// Each subschema is resolved independently so its own $ref / allOf /
// if-then-else are fully expanded before being merged into the accumulator.
// In particular, a branch's `if` is evaluated (and consumed) inside that
// branch's own resolveSchema pass, so several allOf branches carrying their
// own `if` are evaluated independently, as the spec requires. Pinned by the
// 'schema resolution boundary' test group.
// ---------------------------------------------------------------------------

Future<(Schema, ValidationContext)> _resolveAllOf(
  Schema schema,
  Object? data,
  List<String> currentPath,
  ValidationContext context,
  SchemaMerger schemaMerger,
) async {
  final allOfList = schema.allOf;
  if (allOfList == null) return (schema, context);

  var merged = Map<String, dynamic>.of(schema.value)..remove('allOf');
  var currentContext = context;

  for (final subSchema in allOfList) {
    if (subSchema is! Schema) continue;

    final (resolvedSub, resolvedSubContext) = await resolveSchema(
      subSchema,
      data,
      currentPath,
      currentContext,
      schemaMerger,
    );

    currentContext = resolvedSubContext;
    merged = schemaMerger.mergeSchemas(merged, resolvedSub.value);
  }

  return (Schema.fromMap(merged), currentContext);
}

// ---------------------------------------------------------------------------
// Step 3 — if / then / else
//
// After the matching branch is applied, `if`, `then`, and `else` are
// stripped from the result to:
//  • prevent stale re-evaluation on subsequent resolveSchema calls;
//  • keep the resolved schema free of conditional metadata.
// ---------------------------------------------------------------------------
Future<(Schema, ValidationContext)> _resolveIfThenElse(
  Schema schema,
  Object? data,
  List<String> currentPath,
  ValidationContext context,
  SchemaMerger schemaMerger,
) async {
  final ifSchema = schema.ifSchema;
  if (ifSchema == null) return (schema, context);

  // Remove the conditional keys in any case — even if the branch is absent.
  final baseWithoutConditionals = Map<String, dynamic>.of(schema.value)
    ..remove('if')
    ..remove('then')
    ..remove('else');

  // If none of the fields from the if-schema are present in the data —
  // treat the condition as not triggered, as rjsf does.
  if (ifSchema is ObjectSchema && !_hasIfRelevantData(ifSchema as ObjectSchema, data)) {
    return (Schema.fromMap(baseWithoutConditionals), context);
  }

  final ifResult = await validateSubSchema(
    // See normalizeDraft07Tuples: the validator chokes on a list-valued
    // `items` anywhere inside the condition.
    // ignore: unnecessary_cast -- Schema is an extension type, `is` does not promote.
    ifSchema is Schema ? normalizeDraft07Tuples(ifSchema as Schema) : ifSchema,
    data,
    currentPath,
    context,
    [schema],
  );

  final branchSchema = ifResult.isValid ? schema.thenSchema : schema.elseSchema;
  // The branch exists — merge and return.
  if (branchSchema is Schema) {
    final (resolvedBranch, resolvedBranchContext) = await resolveSchema(
      branchSchema,
      data,
      currentPath,
      context,
      schemaMerger,
    );

    return (
      Schema.fromMap(
        schemaMerger.mergeSchemas(baseWithoutConditionals, resolvedBranch.value),
      ),
      resolvedBranchContext,
    );
  }

  // The branch is absent — return the base without the conditional keys.
  return (Schema.fromMap(baseWithoutConditionals), context);
}

/// Returns true if at least one field from the if-schema
/// is present in the current data.
bool _hasIfRelevantData(ObjectSchema ifSchema, Object? data) {
  if (data is! Map<String, dynamic>) return false;

  final ifProperties = ifSchema.properties;
  if (ifProperties == null || ifProperties.isEmpty) return true;

  return ifProperties.keys.any(data.containsKey);
}

// ---------------------------------------------------------------------------
// Step 4 — dependentSchemas
//
// Applied only for keys that are actually present in the data object.
// Schemas for all matching keys are merged in a single pass to avoid
// redundant Schema allocations.
// `dependentSchemas` is stripped after application for the same reasons
// as the conditional keys in step 3.
// ---------------------------------------------------------------------------

Future<(Schema, ValidationContext)> _resolveDependentSchemas(
  Schema schema,
  Object? data,
  List<String> currentPath,
  ValidationContext context,
  SchemaMerger schemaMerger,
) async {
  final dependentSchemas = schema.dependentSchemas;
  if (dependentSchemas == null) return (schema, context);

  final objectData = data is Map<String, dynamic> ? data : null;
  if (objectData == null) return (schema, context);

  final activeKeys = dependentSchemas.keys.where(objectData.containsKey).toList(growable: false);

  if (activeKeys.isEmpty) return (schema, context);

  var merged = Map<String, dynamic>.of(schema.value);
  var currentContext = context;

  for (final key in activeKeys) {
    final (resolvedDep, resolvedDepContext) = await resolveSchema(
      dependentSchemas[key]!,
      data,
      currentPath,
      currentContext,
      schemaMerger,
    );

    currentContext = resolvedDepContext;
    merged = schemaMerger.mergeSchemas(merged, resolvedDep.value);
  }

  merged.remove('dependentSchemas');

  return (Schema.fromMap(merged), currentContext);
}

Future<(Schema, ValidationContext)> _resolveDependentRequired(
  Schema schema,
  Object? data,
  List<String> currentPath,
  ValidationContext context,
) async {
  final dependentRequired = schema.value['dependentRequired'];
  if (dependentRequired is! Map<String, dynamic>) return (schema, context);

  if (data is! Map<String, dynamic>) return (schema, context);

  final additionalRequired = <String>[];

  for (final entry in dependentRequired.entries) {
    if (!data.containsKey(entry.key)) continue;
    final names = entry.value;
    if (names is! List) continue;

    // whereType, not a cast: JSON-decoded schemas carry List<dynamic> (a
    // List<String> cast throws), and non-string entries are malformed —
    // skipped like the non-List branch above.
    additionalRequired.addAll(names.whereType<String>());
  }

  if (additionalRequired.isEmpty) return (schema, context);

  final existing = List<dynamic>.of(schema.value['required'] as List? ?? []);
  final merged = {...existing, ...additionalRequired}.toList();

  final updated = Map<String, dynamic>.of(schema.value)
    ..remove('dependentRequired')
    ..['required'] = merged;

  return (Schema.fromMap(updated), context);
}

Schema _normalizeDependencies(Schema schema) {
  final dependencies = schema.value['dependencies'];
  if (dependencies is! Map<String, dynamic>) return schema;

  final dependentRequired = <String, dynamic>{};
  final dependentSchemas = <String, dynamic>{};

  for (final entry in dependencies.entries) {
    final key = entry.key;
    final value = entry.value;

    if (value is List) {
      // A list → dependentRequired
      dependentRequired[key] = value;
    } else if (value is Map<String, dynamic>) {
      // A schema → dependentSchemas
      dependentSchemas[key] = value;
    }
  }

  final normalized = Map<String, dynamic>.of(schema.value)..remove('dependencies');

  if (dependentRequired.isNotEmpty) {
    normalized['dependentRequired'] = <String, dynamic>{
      ...?normalized['dependentRequired'] as Map<String, dynamic>?,
      ...dependentRequired,
    };
  }

  if (dependentSchemas.isNotEmpty) {
    normalized['dependentSchemas'] = <String, dynamic>{
      ...?normalized['dependentSchemas'] as Map<String, dynamic>?,
      ...dependentSchemas,
    };
  }

  return Schema.fromMap(normalized);
}
