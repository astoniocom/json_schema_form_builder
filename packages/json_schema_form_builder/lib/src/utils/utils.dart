/// Small helpers that fit no theme file: display fallback, object key order,
/// layout constant, standalone validation. Schema-prescribed values live in
/// schema_values.dart, type reasoning in type_matching.dart.
library;

import 'package:json_schema_builder/json_schema_builder.dart';

import '../models/presence_value.dart';
import '../models/schema_validation_mode.dart';

/// Display form of a field value regardless of its type: [notPresented] for
/// an absent value, the literal string `null` for JSON null, toString
/// otherwise. Used where a widget must show SOMETHING for a value it cannot
/// edit (e.g. the checkbox displayValue for a non-bool).
String valueAsString(
  PresenceValue<dynamic> value, {
  String notPresented = '',
}) {
  if (!value.present) return notPresented;

  final raw = value.value;
  if (raw == null) return 'null';

  return value.valueOrNull.toString();
}

/// Display order of an object's keys: the schema's `properties` order first
/// (including keys the data does not have yet), then the data's extra keys in
/// document order. Matches how rjsf lays out object fields.
List<String> resolveOrder({
  required Map<String, dynamic> items,
  required ObjectSchema? schema,
}) {
  final schemaKeys = (schema?.properties ?? {}).keys.toList();
  final userKeys = items.keys.toList();

  return [
    ...schemaKeys,
    ...userKeys.where((k) => !schemaKeys.contains(k)),
  ];
}

/// Default minimal width (logical px) at which inline object/array editors
/// are considered usable; below it they collapse into a compact editor
/// (a button that opens the edit dialog).
const double defaultMinInlineWidth = 300;

/// Deep-normalizes a JSON-like [value] so that every map is a
/// `Map<String, Object?>` and every list a `List<Object?>`.
///
/// Dart literals infer loose types — an untyped `{}` is
/// `Map<dynamic, dynamic>` — while the json_schema_builder validator casts
/// the data it walks to `Map<String, Object?>`, so a literal-built value
/// crashed validation ("_ConstMap<dynamic, dynamic> is not a subtype ...").
/// Every validator entry point routes its data through this normalization;
/// JSON-decoded data passes through unchanged in shape. Non-string map keys
/// (malformed JSON data) are coerced with toString instead of crashing.
Object? normalizeJsonValue(Object? value) {
  return switch (value) {
    final Map<dynamic, dynamic> map => <String, Object?>{
      for (final entry in map.entries) entry.key.toString(): normalizeJsonValue(entry.value),
    },
    final List<dynamic> list => <Object?>[for (final item in list) normalizeJsonValue(item)],
    _ => value,
  };
}

/// Keywords whose value is a map of subschemas. `dependencies` values may
/// also be plain name lists (draft-07); the walk only descends into map
/// values, so those pass through.
const _mapOfSchemasKeywords = {'properties', 'patternProperties', r'$defs', 'definitions', 'dependentSchemas', 'dependencies'};

/// Keywords whose value is a list of subschemas.
const _listOfSchemasKeywords = {'allOf', 'anyOf', 'oneOf', 'prefixItems'};

/// Keywords whose value is a single subschema.
const _singleSchemaKeywords = {
  'additionalProperties',
  'additionalItems',
  'not',
  'if',
  'then',
  'else',
  'contains',
  'propertyNames',
  'unevaluatedItems',
  'unevaluatedProperties',
};

/// Rewrites draft-07 tuple syntax into the 2020-12 spelling, deeply:
/// a list-valued `items` becomes `prefixItems`, and `additionalItems`
/// (the "beyond the tuple" schema) becomes `items`.
///
/// The bundled validator (json_schema_builder) speaks 2020-12 only — fed a
/// draft-07 tuple it throws a cast error, which surfaces as "validator
/// rejected schema" and (under strict mode) blocks submission. Every
/// validator entry point routes its schema through this normalization, the
/// same policy as [normalizeJsonValue] for data. Rendering needs no rewrite:
/// ArrayFieldHandler reads both dialects natively.
///
/// The walk is schema-aware: it descends only into keyword positions that
/// hold subschemas, so an `items` key inside a `const`/`enum`/`default`
/// VALUE is data and stays untouched. A schema already carrying
/// `prefixItems` next to a list-valued `items` is contradictory;
/// `prefixItems` wins and the list is dropped. A 2020-12 document passes
/// through as the same instance.
Schema normalizeDraft07Tuples(Schema schema) {
  if (!_containsListItems(schema.value)) return schema;
  return Schema.fromMap(_normalizeTuples(schema.value));
}

/// The cheap scan deciding whether a rewrite pass is needed at all. Blunt on
/// purpose (a list-valued `items` key inside a const/enum value also
/// triggers it): a false positive only costs a copy — the rewrite itself is
/// schema-aware.
bool _containsListItems(Object? node) {
  if (node is Map) {
    if (node['items'] is List) return true;
    return node.values.any(_containsListItems);
  }
  if (node is List) return node.any(_containsListItems);
  return false;
}

/// [_normalizeTuples] for a value that may or may not be a subschema map
/// (booleans are valid schemas and pass through).
Object? _normalizeTuplesInNode(Object? node) => node is Map ? _normalizeTuples(node) : node;

Map<String, Object?> _normalizeTuples(Map<dynamic, dynamic> schema) {
  final result = <String, Object?>{};
  for (final entry in schema.entries) {
    final key = entry.key.toString();
    final value = entry.value;
    result[key] = switch (value) {
      final List<dynamic> tuple when key == 'items' || _listOfSchemasKeywords.contains(key) => <Object?>[
        for (final item in tuple) _normalizeTuplesInNode(item),
      ],
      final Map<dynamic, dynamic> subschemas when _mapOfSchemasKeywords.contains(key) => <String, Object?>{
        for (final sub in subschemas.entries) sub.key.toString(): _normalizeTuplesInNode(sub.value),
      },
      final Map<dynamic, dynamic> subschema when key == 'items' || _singleSchemaKeywords.contains(key) => _normalizeTuples(subschema),
      _ => value,
    };
  }

  final items = result['items'];
  if (items is List) {
    result.remove('items');
    result.putIfAbsent('prefixItems', () => items);
    final additional = result.remove('additionalItems');
    if (additional != null) result['items'] = additional;
  }
  return result;
}

/// Meta-schema URIs pre-registered in every validation registry built by
/// [buildStandaloneValidationContext], so that a document's `$schema` keyword
/// never triggers a network fetch (which fails offline and on the web due to
/// CORS: "Failed to resolve meta schema"). The registered stub carries no
/// `$vocabulary`, which makes the validator fall back to the full default
/// 2020-12 vocabulary set -- the behavior a schema without `$schema` gets
/// anyway.
final List<Uri> _wellKnownMetaSchemaUris = [
  Uri.parse('https://json-schema.org/draft/2020-12/schema'),
  Uri.parse('https://json-schema.org/draft/2019-09/schema'),
  Uri.parse('https://json-schema.org/draft-07/schema'),
  Uri.parse('http://json-schema.org/draft-07/schema'),
  Uri.parse('http://json-schema.org/draft-06/schema'),
  Uri.parse('http://json-schema.org/draft-04/schema'),
];

/// Builds a ValidationContext for validating data against [itemSchema]:
/// the root document ([rootSchema], falling back to [itemSchema]) is
/// registered so `$ref`s pointing into it resolve (including bundled
/// subschemas carrying their own `$id`), and the well-known meta-schema URIs
/// are stubbed out so `$schema` never triggers a network fetch.
///
/// The caller owns the returned SchemaRegistry and must dispose it on every
/// code path (see JsonHandlerRegistry.withValidationContext for the managed
/// wrapper).
(ValidationContext, SchemaRegistry) buildStandaloneValidationContext({
  required Schema itemSchema,
  Schema? rootSchema,
}) {
  final schemaRegistry = SchemaRegistry();
  // Normalized so that `$ref` targets containing draft-07 tuples resolve to
  // a form the validator can process (see normalizeDraft07Tuples).
  final rootDocument = normalizeDraft07Tuples(rootSchema ?? itemSchema);
  // The base URI must honor the document's own `$id`: relative `$ref`s such
  // as "/schemas/mixins/integer" resolve against it, and bundled subschemas
  // carrying absolute `$id`s are registered relative to it too. Without
  // this, refs would resolve against the synthetic local:// URI and miss.
  var baseUri = Uri.parse('local://schema');
  final rootId = rootDocument.$id;
  if (rootId != null) {
    // resolve() also covers a relative $id by keeping the local:// base.
    baseUri = baseUri.resolve(rootId).removeFragment();
  }
  schemaRegistry.addSchema(baseUri, rootDocument);
  for (final metaSchemaUri in _wellKnownMetaSchemaUris) {
    schemaRegistry.addSchema(metaSchemaUri, Schema.fromMap(const {}));
  }
  return (
    ValidationContext(
      itemSchema,
      sourceUri: baseUri,
      schemaRegistry: schemaRegistry,
    ),
    schemaRegistry,
  );
}

/// Standalone validation of [data] against [schema] that never throws: a
/// schema the validator cannot process surfaces as a single visible custom
/// error ([validatorRejectedSchemaErrors]) instead of crashing the caller
/// (the same policy as JsonHandlerRegistry.validateValue). The validation
/// context comes from [buildStandaloneValidationContext]: [schema] is its
/// own root document, and the `$schema` keyword resolves against the
/// pre-registered meta-schema stubs instead of the network (a plain
/// `schema.validate` fetches the meta schema, which fails offline and on
/// the web: "Failed to resolve meta schema"). Null when [schema] is null
/// (nothing to validate against).
Future<List<ValidationError>?> validateDataBySchema(Schema? schema, Object? data) async {
  if (schema == null) return null;

  final normalizedSchema = normalizeDraft07Tuples(schema);
  final (validationContext, schemaRegistry) = buildStandaloneValidationContext(itemSchema: normalizedSchema);
  try {
    final result = await normalizedSchema.validateSchema(normalizeJsonValue(data), [], validationContext, [normalizedSchema]);
    return result.errors;
  } catch (e) {
    return validatorRejectedSchemaErrors(e);
  } finally {
    schemaRegistry.dispose();
  }
}
