import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/schema_validation_mode.dart';
import '../../utils/utils.dart';

/// The schemas applying to the property [key] of [objectSchema]: the exact
/// `properties` entry and every matching `patternProperties` entry, falling
/// back to a schema-valued `additionalProperties`; empty when nothing
/// constrains the key.
List<Schema> computeSchemasForKey(ObjectSchema objectSchema, String key, Map<RegExp, Schema> fieldNamePatterns) {
  // 1. Exact match in properties
  final fromProperties = objectSchema.properties?[key];

  // 2. Matches via patternProperties
  final fromPatterns = fieldNamePatterns.entries.where((mapEntry) => mapEntry.key.hasMatch(key)).map((e) => e.value).toList(growable: false);

  final matched = [
    if (fromProperties != null) fromProperties,
    ...fromPatterns,
  ];

  if (matched.isEmpty) {
    // 3. Fallback to additionalProperties
    final additionalPropertiesSchema = objectSchema.additionalProperties;

    // If it is a Map — parse the schema
    if (additionalPropertiesSchema != null && additionalPropertiesSchema.value.isNotEmpty) {
      return [additionalPropertiesSchema];
    }

    // In all other cases (true, false, null) return an empty list
    return [];
  }

  return matched;
}

/// Whether [schema] admits additional properties;
/// [treatUnspecifiedAsForbidden] decides the unspecified case (the spec says
/// allowed, ObjectFieldHandler.requireExplicitAdditionalProperties flips it).
bool resolveAdditionalPropertiesAllowed(
  ObjectSchema? schema, {
  required bool treatUnspecifiedAsForbidden,
}) {
  if (schema == null) return true;
  final raw = schema.value['additionalProperties'];
  if (raw == null) return !treatUnspecifiedAsForbidden;
  return raw != false;
}

/// Validates [value] against every schema of [schemasToValidate] (each in
/// its own standalone context) and concatenates the errors; a schema the
/// validator cannot process contributes the validator-rejected sentinel
/// error instead of throwing.
Future<List<ValidationError>> validateValue({
  required List<Schema> schemasToValidate,
  required dynamic value,
}) async {
  try {
    // See normalizeJsonValue: literal-built maps crash the validator's casts.
    final normalizedValue = normalizeJsonValue(value);
    // Run validation against all schemas in parallel. Each gets a standalone
    // context (instead of a plain schema.validate) so a `$schema` keyword
    // resolves against the pre-registered meta-schema stubs rather than
    // triggering a network fetch that fails offline and on the web.
    final results = await Future.wait(
      schemasToValidate.map((schema) async {
        // See normalizeDraft07Tuples: a list-valued `items` crashes the
        // validator otherwise.
        final normalizedSchema = normalizeDraft07Tuples(schema);
        final (validationContext, schemaRegistry) = buildStandaloneValidationContext(itemSchema: normalizedSchema);
        try {
          final result = await normalizedSchema.validateSchema(normalizedValue, [], validationContext, [normalizedSchema]);
          return result.errors;
        } finally {
          schemaRegistry.dispose();
        }
      }),
    );

    // Merge all errors into one flat list
    return results.expand((errors) => errors).toList(growable: false);
  } catch (e) {
    // Same policy as validateDataBySchema: a schema the validator cannot
    // process must surface as a visible error, not crash the dialog.
    return validatorRejectedSchemaErrors(e);
  }
}
