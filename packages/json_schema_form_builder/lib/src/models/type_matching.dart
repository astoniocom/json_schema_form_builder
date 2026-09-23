/// Type reasoning: mapping values and schemas to Dart / JSON Schema types,
/// and synthesizing single-type branches from a union `type` list.
library;

import 'package:collection/collection.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import 'presence_value.dart';
import 'schema_values.dart';

/// The canonical Dart type of a decoded JSON value: the vocabulary of
/// JsonHandlerRegistration.valueTypes and of the canEditValue
/// implementations. Both sides of the value-based handler lookup must use
/// this function rather than runtimeType (e.g. any Map normalizes to
/// `Map<String, dynamic>`, any List to `List<dynamic>`).
Type dartTypeOfValue(dynamic value) => switch (value) {
  null => Null,
  bool _ => bool,
  int _ => int,
  double _ => double,
  String _ => String,
  List _ => List<dynamic>, // ignore: strict_raw_type
  Map _ => Map<String, dynamic>, // ignore: strict_raw_type
  _ => Object,
};

/// Whether [schema] explicitly admits null via a union type
/// (`"type": [..., "null"]`).
bool isNullableSchema(Schema? schema) {
  final type = schema?.type;
  return type is List && type.contains('null');
}

/// Whether [schema] declares its own `anyOf`/`oneOf` alternatives.
///
/// This is the discriminator between the two kinds of variants a field state
/// can carry: declared alternatives REFINE the base schema (an object then
/// renders its own editor plus the switcher and merges branch writes into
/// the value), while variants synthesized from the `type` keyword (see
/// [synthesizedTypeBranchSchemas]) are COMPLETE alternatives (only the
/// switcher renders and branch writes replace the value wholesale).
///
/// NB: Schema is an extension type over Map, so `is ObjectSchema`-style
/// checks cannot tell schema kinds apart (every schema "is" every subtype);
/// the raw keywords are the only reliable discriminator.
bool schemaHasOwnAlternatives(Schema? schema) => schema != null && (schema.value['anyOf'] != null || schema.value['oneOf'] != null);

/// JSON Schema type of a decoded JSON value (e.g. used to narrow a schema's
/// accepted types by the current value).
JsonType? jsonTypeOfValue(dynamic value) => switch (value) {
  null => JsonType.nil,
  bool _ => JsonType.boolean,
  int _ => JsonType.int,
  double _ => JsonType.num,
  String _ => JsonType.string,
  List<dynamic> _ => JsonType.list,
  Map<dynamic, dynamic> _ => JsonType.object,
  _ => null,
};

/// The canonical empty value of a container-typed [schema]: `{}` when it
/// accepts exactly the object type, `[]` when exactly the array type, absent
/// otherwise (scalars, unions, unconstrained). Document-local `$ref`s and
/// `allOf` are expanded first ([expandedLocalSchemaMap]), so a `{$ref: ...}`
/// branch reveals its target's type.
///
/// Used by the variant switch write policy: selecting a container branch
/// must materialize in the document (rjsf's getDefaultFormState yields
/// `{}`/`[]` there), or the selection would not survive a dialog roundtrip —
/// the committed value (null/absent) would match a different branch on
/// rebuild. Scalars deliberately stay absent (also rjsf parity: an untouched
/// string branch writes nothing).
PresenceValue<Object?> containerEmptyValue(Schema? schema, {Schema? rootSchema}) {
  final map = expandedLocalSchemaMap(schema, rootSchema: rootSchema);
  if (map == null) return const PresenceValue.absent();

  final types = typesAcceptedBy(Schema.fromMap(map));
  if (types.length != 1) return const PresenceValue.absent();

  return switch (types.single) {
    JsonType.object => const PresenceValue(<String, Object?>{}),
    JsonType.list => const PresenceValue(<Object?>[]),
    _ => const PresenceValue.absent(),
  };
}

/// JSON Schema types accepted by [schema]: the explicit `type` keyword when
/// present, otherwise inferred from characteristic keywords and enum/const
/// samples. An empty list means the schema does not constrain the type.
List<JsonType> typesAcceptedBy(Schema schema) {
  final type = schema.type;

  final List<String> typeNames = switch (type) {
    final String s => [s],
    final List<dynamic> l when l.isNotEmpty => l.whereType<String>().toList(growable: false),
    _ => _inferTypeNames(schema), // ← type inference when not specified explicitly
  };

  return typeNames.map(_jsonTypeByName).nonNulls.toList(growable: false);
}

JsonType? _jsonTypeByName(String typeName) {
  for (final jsonType in JsonType.values) {
    if (jsonType.typeName == typeName) return jsonType;
  }
  return null;
}

const _objectKeywords = {
  'properties',
  'additionalProperties',
  'patternProperties',
  'required',
  'minProperties',
  'maxProperties',
  'dependentSchemas',
  'dependentRequired',
};

const _arrayKeywords = {
  'items',
  'prefixItems',
  'additionalItems',
  'minItems',
  'maxItems',
  'uniqueItems',
  'contains',
};

const _stringKeywords = {
  'minLength',
  'maxLength',
  'pattern',
  'format',
};

const _numberKeywords = {
  'minimum',
  'maximum',
  'exclusiveMinimum',
  'exclusiveMaximum',
  'multipleOf',
};

List<String> _inferTypeNames(Schema schema) {
  final keys = schema.value.keys.toSet();
  final inferred = <String>{};

  if (keys.intersection(_objectKeywords).isNotEmpty) inferred.add('object');
  if (keys.intersection(_arrayKeywords).isNotEmpty) inferred.add('array');
  if (keys.intersection(_stringKeywords).isNotEmpty) inferred.add('string');
  if (keys.intersection(_numberKeywords).isNotEmpty) inferred.add('number');

  // enum/const — infer the type from the first value
  final enumValues = schema.value['enum'] as List?;
  final constValue = schema.value['const'];

  final sample = enumValues?.firstOrNull ?? constValue;
  if (sample != null) {
    final enumTypeName = jsonTypeOfValue(sample)?.typeName;
    if (enumTypeName != null) inferred.add(enumTypeName);
  }

  return inferred.toList(growable: false);
}

/// The branch types synthesized for a schema that does not constrain the
/// type at all: every JSON type, "integer" before "number" so an integer
/// value initially selects the Int editor on an equal-score tie
/// (closestVariantIndices keeps insertion order).
///
/// "null" is excluded, mirroring the union synthesis below: a schema that
/// admits everything admits null, so clearing the selected branch's editor
/// writes an explicit null (see JsonFieldHandler.normalizedEmptyValue) —
/// a dedicated null branch would only duplicate that path.
const _unconstrainedTypeNames = ['string', 'integer', 'number', 'boolean', 'object', 'array'];

/// Single-type branch schemas synthesized from a union `type` list
/// (`type: ["string", "integer"]`). JSON Schema validation keywords are
/// type-scoped, so such a schema is equivalent to an `anyOf` of the same
/// schema narrowed to each type; the branches feed the regular Variant
/// switcher, letting the user pick which type to enter.
/// (react-jsonschema-form just renders the first type of the list, leaving
/// the other types unreachable from the form.)
///
/// A schema that does not constrain the type AT ALL (no `type`, nothing to
/// infer it from — [typesAcceptedBy] is empty, e.g. the empty schema `{}`)
/// is the extreme of the same situation: a union of every JSON type
/// ([_unconstrainedTypeNames]). Without the synthesis such a field would
/// dead-end in the read-only unknown editor, with no way to start entering
/// a value.
///
/// Null (no synthesis) when:
/// - fewer than two non-"null" types remain: the nullable idiom
///   `type: ["string", "null"]` stays a single field whose clearing writes an
///   explicit null (see JsonFieldHandler.normalizedEmptyValue);
/// - the schema has `enum` or `const`: the value picker already fixes both
///   the value and its type;
/// - the type, while not spelled out, is inferable from characteristic
///   keywords (`{"properties": ...}` implies an object): the inferred
///   editor is already reachable, a switcher of all types would be noise.
///
/// The caller must ensure the schema carries no own `anyOf`/`oneOf`: those
/// take precedence (each alternative constrains the union further), and
/// mixing them with synthesized branches would double the switcher.
List<Schema>? synthesizedTypeBranchSchemas(Schema schema) {
  if (schemaHasConst(schema) || (schema.enumValues?.isNotEmpty ?? false)) return null;

  final type = schema.type;
  final List<String> nonNullTypeNames;
  var unconstrained = false;
  if (type is List) {
    // The spec requires the entries of a `type` list to be unique; tolerate
    // duplicates anyway (toSet keeps the first occurrence order) instead of
    // synthesizing identical branches for the switcher.
    nonNullTypeNames = type.whereType<String>().where((name) => name != 'null').toSet().toList(growable: false);
    if (nonNullTypeNames.length < 2) return null;
  } else if (type == null && typesAcceptedBy(schema).isEmpty) {
    nonNullTypeNames = _unconstrainedTypeNames;
    unconstrained = true;
  } else {
    return null;
  }

  return [
    for (final typeName in nonNullTypeNames)
      Schema.fromMap(
        {
          ...schema.value,
          'type': typeName,
          // The Variant dropdown labels alternatives by title; the parent's
          // title would make the branches indistinguishable.
          'title': typeName,
          // The unconstrained schema admits any object, which is exactly
          // additionalProperties: true — and the branch must say so
          // explicitly, because under the strict
          // ObjectFieldHandler.requireExplicitAdditionalProperties policy an
          // object schema that leaves it unspecified renders a dead-end
          // editor: no declared properties and no add button. The base
          // schema cannot carry its own object keywords on this path
          // (typesAcceptedBy would have inferred "object" from them).
          if (unconstrained && typeName == 'object') 'additionalProperties': true,
        }..removeWhere(
          // A `default` of a foreign type must not leak into a branch:
          // switching to the branch writes its default into the document
          // (applyVariantSwitched), and e.g. a string default inside the
          // integer branch would corrupt it.
          (key, value) => key == 'default' && !_typeNameAdmitsValue(typeName, value),
        ),
      ),
  ];
}

bool _typeNameAdmitsValue(String typeName, Object? value) {
  final valueType = jsonTypeOfValue(value);
  if (valueType == null) return false;
  if (valueType.typeName == typeName) return true;
  // JSON Schema "number" admits integer values too.
  return typeName == 'number' && valueType == JsonType.int;
}
