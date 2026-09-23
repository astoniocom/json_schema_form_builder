/// Schema-prescribed values: const/single-enum pinning, seeds for newly
/// created fields, select-like option enumeration, and the single write
/// policy of representation switching built on top of them.
library;

import 'package:flutter/foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../schema_resolver/models/exceptions.dart';
import '../schema_resolver/schema_merger.dart';
import 'presence_value.dart';

/// Whether [schema] pins the value with the `const` keyword.
/// `containsKey` (not a null check) so that `const: null` is honored too.
bool schemaHasConst(Schema? schema) => schema?.value.containsKey('const') ?? false;

/// The value [schema] admits as the only one: `const`, a single-element
/// `enum` (react-jsonschema-form's isConstant), or the `null` type — its
/// value domain is the single value null, so `type: "null"` pins exactly
/// like `const: null` (rjsf reaches the same result differently: its null
/// field renders no input and writes null on mount). Absent when the schema
/// does not pin the value. Used where selecting an anyOf/oneOf alternative
/// must write the value it stands for.
PresenceValue<Object?> schemaPinnedValue(Schema? schema) {
  if (schema == null) return const PresenceValue.absent();
  if (schemaHasConst(schema)) return PresenceValue(schema.value['const']);

  final enumValues = schema.value['enum'];
  if (enumValues is List && enumValues.length == 1) return PresenceValue(enumValues.first);

  final type = schema.value['type'];
  if (type == 'null' || (type is List && type.length == 1 && type.single == 'null')) {
    return const PresenceValue(null);
  }

  return const PresenceValue.absent();
}

/// The single write policy for switching a value's representation — an
/// anyOf/oneOf branch in the Variant switcher or a value type in the entry
/// dialog's picker. Both UIs must route through this function so the written
/// value does not depend on where the user initiated the switch.
///
/// Order: pinned value of [targetSchema] ([schemaPinnedValue]: `const` or a
/// single-element `enum`; the old value cannot satisfy the new
/// representation) → the present [currentValue] → the schema seed
/// ([schemaSeedValue]: `const`, `default`, recursive object property
/// defaults) → [emptySeed] → [currentValue] as is (absent).
///
/// [admits] gates pinned/seed values by the target representation's type
/// (the entry dialog passes the handler's canEditValue check; a branch
/// switch admits everything — the branch schema is the representation).
/// [emptySeed] is the caller's empty-value policy: the entry dialog passes
/// the handler's canonicalEmptyValue (committing an untouched container must
/// write []/{}/'' instead of null); a branch switch passes the container
/// empty value ({} / [], see containerEmptyValue in type_matching.dart) so
/// the selection materializes in the document, and nothing for scalar
/// branches — an untouched scalar branch stays absent (matches rjsf).
///
/// [rootSchema] (the WHOLE document's schema) lets the seed lookup follow
/// document-local `$ref`s inside property schemas (see [schemaSeedValue]).
PresenceValue<dynamic> switchRepresentationValue({
  required Schema? targetSchema,
  required PresenceValue<dynamic> currentValue,
  bool Function(Object? value)? admits,
  PresenceValue<dynamic>? emptySeed,
  Schema? rootSchema,
}) {
  bool admitted(Object? value) => admits == null || admits(value);

  final pinned = schemaPinnedValue(targetSchema);
  if (pinned.present && admitted(pinned.valueOrNull)) return PresenceValue(pinned.valueOrNull);

  if (currentValue.present) return currentValue;

  final seed = schemaSeedValue(targetSchema, rootSchema: rootSchema);
  if (seed.present && admitted(seed.valueOrNull)) return PresenceValue(seed.valueOrNull);

  if (emptySeed != null) return emptySeed;

  return currentValue;
}

/// A fixed option of a select-like schema: the admitted value and the label
/// it is displayed with.
class EnumOption {
  /// Creates an option displaying [value] as [label].
  const EnumOption({
    required this.value,
    required this.label,
  });

  /// The JSON value the option writes when selected.
  final Object? value;

  /// The text the option is displayed with.
  final String label;
}

/// The full set of values a select-like schema admits, paired with display
/// labels (react-jsonschema-form's optionsList): either a plain `enum`, or
/// `anyOf`/`oneOf` where every alternative pins its value
/// ([schemaPinnedValue]) and the label comes from the alternative's `title`.
/// Null when the schema is not select-like.
List<EnumOption>? schemaEnumOptions(Schema? schema) {
  if (schema == null) return null;

  final enumValues = schema.enumValues;
  if (enumValues != null) {
    return [for (final value in enumValues) EnumOption(value: value, label: value.toString())];
  }

  final alternatives = schema.anyOf ?? schema.oneOf;
  if (alternatives == null || alternatives.isEmpty) return null;

  final options = <EnumOption>[];
  for (final rawAlternative in alternatives) {
    final alternative = _asSchema(rawAlternative);
    final pinned = schemaPinnedValue(alternative);
    if (!pinned.present) return null;
    options.add(EnumOption(value: pinned.valueOrNull, label: alternative?.title ?? pinned.valueOrNull.toString()));
  }
  return options;
}

/// The value a schema prescribes for a newly created field: `const` wins,
/// then `default`, then -- for objects -- the property defaults collected
/// recursively. An object's own `default` and its property defaults are
/// merged per key, the explicit default winning and the property defaults
/// filling the keys it does not cover; the merge is deep, following
/// react-jsonschema-form's computeDefaults (a default handed down by the
/// parent takes precedence over the schema's own `default` on every level).
/// Absent when the schema prescribes nothing.
///
/// With [rootSchema] (the WHOLE document's schema) the lookup follows
/// document-local `$ref`s (`#/...` JSON pointers, e.g. `#/$defs/x`) and
/// flattens `allOf` inside property schemas, so `default`/`const` hidden
/// behind them are picked up too (rjsf's computeDefaults parity). A `$ref`
/// already expanded on the current descent is left unexpanded, so recursive
/// schemas terminate after one level.
///
/// Known limitation: non-local `$ref`s (remote URLs, `$id`-relative paths,
/// `$anchor`) are not followed — seeds behind them are not picked up.
PresenceValue<Object?> schemaSeedValue(Schema? schema, {Schema? rootSchema}) =>
    _schemaSeedValue(_asRawSchema(schema), const PresenceValue.absent(), rootSchema, const {});

PresenceValue<Object?> _schemaSeedValue(
  Map<String, Object?>? rawSchema,
  PresenceValue<Object?> parentDefault,
  Schema? rootSchema,
  Set<String> visitedRefs,
) {
  if (rawSchema == null) return parentDefault;

  final (map, visited) = _expandLocalRefs(rawSchema, rootSchema, visitedRefs);

  if (map.containsKey('const')) return PresenceValue(map['const']);

  final PresenceValue<Object?> ownDefault = parentDefault.present
      ? parentDefault
      : map.containsKey('default')
      ? PresenceValue(map['default'])
      : const PresenceValue.absent();

  final properties = map['properties'];
  final rawDefault = ownDefault.valueOrNull;

  // A non-object default (or a schema without properties) cannot be merged
  // per key and is taken as is.
  if (properties is! Map || (ownDefault.present && rawDefault is! Map)) return ownDefault;

  final base = rawDefault is Map ? Map<String, Object?>.from(rawDefault) : <String, Object?>{};

  final seeds = <String, Object?>{};
  for (final entry in properties.entries) {
    final key = entry.key.toString();
    final childParent = base.containsKey(key) ? PresenceValue<Object?>(base[key]) : const PresenceValue<Object?>.absent();
    final seed = _schemaSeedValue(_asRawSchema(entry.value), childParent, rootSchema, visited);
    if (seed.present) seeds[key] = seed.valueOrNull;
  }
  // Keys of the explicit default that no property describes.
  for (final entry in base.entries) {
    seeds.putIfAbsent(entry.key, () => entry.value);
  }

  if (seeds.isEmpty && !ownDefault.present) return const PresenceValue.absent();
  return PresenceValue(seeds);
}

/// Best-effort synchronous view of [schema] with document-local `$ref`s and
/// `allOf` expanded (the seed lookup's expansion, see [schemaSeedValue]);
/// the raw map unchanged when nothing expands, null when [schema] is null.
///
/// For callers that must reason about a branch schema's effective keywords
/// (e.g. its `type`) without the async resolver — a `{$ref: ...}` branch
/// reveals its target's type here.
Map<String, Object?>? expandedLocalSchemaMap(Schema? schema, {Schema? rootSchema}) {
  final raw = _asRawSchema(schema);
  if (raw == null) return null;
  final (map, _) = _expandLocalRefs(raw, rootSchema, const {});
  return map;
}

/// Shared merge semantics with the full resolver (schema_resolver.dart):
/// local siblings override the `$ref` target, `allOf` branches flatten into
/// the base in order.
final SchemaMerger _seedMerger = SchemaMerger.withDefaults();

/// Best-effort synchronous expansion of the wrappers that hide seed
/// keywords: a document-local `$ref` (a `#/...` JSON pointer into
/// [rootSchema]) and `allOf`. Unlike the full (async) resolver this needs no
/// ValidationContext, so it stays callable from the sync switch policy.
///
/// Returns the effective map plus the refs consumed on this descent
/// ([visitedRefs] grown per expansion): a ref already on the path is left
/// unexpanded, so recursive schemas terminate. Non-local refs, unresolvable
/// pointers and unsatisfiable merges leave the map unexpanded — the seed is
/// then simply not found, which is the pre-expansion behavior.
(Map<String, Object?>, Set<String>) _expandLocalRefs(
  Map<String, Object?> rawSchema,
  Schema? rootSchema,
  Set<String> visitedRefs,
) {
  var map = rawSchema;
  var visited = visitedRefs;

  // $ref chains ($ref -> $ref): the merged target may itself carry a $ref.
  while (true) {
    final ref = map[r'$ref'];
    if (ref is! String || !ref.startsWith('#/') || rootSchema == null || visited.contains(ref)) break;

    final target = _resolveJsonPointer(rootSchema.value, ref);
    if (target is! Map) break;

    visited = {...visited, ref};
    final localWithoutRef = Map<String, Object?>.of(map)..remove(r'$ref');
    final merged = _mergeForSeed(Map<String, Object?>.from(target), localWithoutRef);
    if (merged == null) break;
    map = merged;
  }

  final allOf = map['allOf'];
  if (allOf is List && allOf.isNotEmpty) {
    var merged = Map<String, Object?>.of(map)..remove('allOf');
    for (final branch in allOf) {
      final branchMap = _asRawSchema(branch);
      if (branchMap == null) continue;
      final (expandedBranch, branchVisited) = _expandLocalRefs(branchMap, rootSchema, visited);
      visited = branchVisited;
      final next = _mergeForSeed(merged, expandedBranch);
      if (next == null) return (map, visited); // unsatisfiable: keep unexpanded
      merged = next;
    }
    map = merged;
  }

  return (map, visited);
}

Map<String, Object?>? _mergeForSeed(Map<String, Object?> a, Map<String, Object?> b) {
  try {
    return Map<String, Object?>.from(_seedMerger.mergeSchemas(a, b));
  } on SchemaMergeException catch (e) {
    debugPrint('schemaSeedValue: unsatisfiable merge while expanding a local \$ref/allOf, seed lookup skips it: $e');
    return null;
  }
}

/// Resolves a document-local JSON pointer (`#/a/b/0`) against [document].
/// Null when any segment is missing — the caller then leaves the `$ref`
/// unexpanded.
Object? _resolveJsonPointer(Map<String, Object?> document, String ref) {
  Object? node = document;
  for (final rawSegment in ref.substring(2).split('/')) {
    // RFC 6901 unescaping; the pointer lives in a URI fragment, so segments
    // may come percent-encoded. Malformed escapes (a '%' not followed by two
    // hex digits would make decodeComponent throw) keep the raw segment.
    var segment = rawSegment;
    if (segment.contains('%') && !_malformedPercentEscape.hasMatch(segment)) {
      segment = Uri.decodeComponent(segment);
    }
    segment = segment.replaceAll('~1', '/').replaceAll('~0', '~');

    switch (node) {
      case final Map<dynamic, dynamic> mapNode when mapNode.containsKey(segment):
        node = mapNode[segment];
      case final List<dynamic> listNode:
        final index = int.tryParse(segment);
        if (index == null || index < 0 || index >= listNode.length) return null;
        node = listNode[index];
      default:
        return null;
    }
  }
  return node;
}

/// A `%` not opening a two-hex-digit escape (see [_resolveJsonPointer]).
final RegExp _malformedPercentEscape = RegExp('%(?![0-9A-Fa-f]{2})');

Map<String, Object?>? _asRawSchema(Object? raw) {
  if (raw is Schema) return Map<String, Object?>.from(raw.value);
  if (raw is Map) return Map<String, Object?>.from(raw);
  return null;
}

Schema? _asSchema(Object? raw) {
  if (raw is Schema) return raw;
  if (raw is Map) return Schema.fromMap(Map<String, Object?>.from(raw));
  return null;
}
