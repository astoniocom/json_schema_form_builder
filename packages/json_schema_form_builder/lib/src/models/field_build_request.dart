import 'package:json_schema_builder/json_schema_builder.dart';

import 'field_context.dart';
import 'json_field_state.dart';
import 'presence_value.dart';

/// A schema paired with the [ValidationContext] able to resolve its `$ref`s
/// (the context's SchemaRegistry holds the root document at the source URI).
///
/// The pairing is structural on purpose: a schema without a resolve context
/// silently degrades `$ref` resolution and root-aware validation, so
/// [FieldBuildRequest] carries them only together. Callers with an optional
/// schema use [SchemaWithContext.maybe].
///
/// Must not outlive the JsonHandlerRegistry.withValidationContext scope that
/// created [validationContext]: the backing SchemaRegistry is disposed there.
class SchemaWithContext {
  /// Pairs [schema] with the context able to resolve its `$ref`s.
  const SchemaWithContext({required this.schema, required this.validationContext});

  /// The schema fragment describing the field.
  final Schema schema;

  /// The validation context whose SchemaRegistry resolves the schema's
  /// `$ref`s and anchors validation at the root document.
  final ValidationContext validationContext;

  /// Null when [schema] is null (no schema at all). [validationContext] must
  /// be non-null whenever [schema] is non-null: a schema always originates
  /// from a pipeline that created a context for it (usually
  /// JsonHandlerRegistry.withValidationContext).
  static SchemaWithContext? maybe(Schema? schema, ValidationContext? validationContext) {
    if (schema == null) return null;
    return SchemaWithContext(schema: schema, validationContext: validationContext!);
  }
}

/// Parameter object for the state building pipeline
/// (JsonHandlerRegistry.buildState -> JsonFieldStateBuilder.buildState).
///
/// Adding a new input to the pipeline means adding a field here instead of
/// threading one more named parameter through the registry, ten handler
/// implementations and every call site.
class FieldBuildRequest {
  /// Creates a build request; the registry fills the derived parts
  /// ([fieldAnnotations], [variants]) during enrichment.
  const FieldBuildRequest({
    required this.value,
    required this.resolveContext,
    this.schemaSource,
    this.errors,
    this.title,
    this.readOnly = false,
    this.required,
    this.fieldAnnotations,
    this.variants,
    this.matchedVariantIndices = const {},
  });

  /// Current JSON value of the field (absent when the key is missing).
  final PresenceValue<dynamic> value;

  /// Schema of the field with its resolve context; null when editing
  /// schema-less JSON. The registry replaces it with the resolved
  /// ($ref/allOf) schema before dispatching to the handler.
  final SchemaWithContext? schemaSource;

  /// Schema describing the field; null when editing schema-less JSON.
  Schema? get schema => schemaSource?.schema;

  /// Validation context used to resolve $ref/allOf while building.
  ValidationContext? get schemaResolveContext => schemaSource?.validationContext;

  /// Validation errors already known for this field (carried over from a
  /// previous state so a rebuild does not lose them).
  final List<ValidationError>? errors;

  /// Where in the document the field sits and how it was reached (path,
  /// root schema, expanded `$ref`s for the cycle guard).
  final FieldResolveContext resolveContext;

  /// The field label; when null the registry derives it from the schema.
  final String? title;

  /// Read-only flag inherited from the parent or the caller. The registry
  /// merges it with schema.readOnly into [fieldAnnotations].
  final bool readOnly;

  /// Whether the field is listed in the parent object's `required`.
  final bool? required;

  /// Computed by the registry (from the resolved schema, [readOnly] and
  /// [required]) before dispatching to the handler; null until that stage.
  final FieldAnnotations? fieldAnnotations;

  /// States of the anyOf/oneOf alternatives (including single-type branches
  /// synthesized for a union `type` list). Built by the registry as the last
  /// enrichment step before dispatching to the handler; null when the schema
  /// carries no alternatives (or until that stage).
  final List<JsonFieldState>? variants;

  /// Indices in [variants] whose schema matches the current value. Computed
  /// together with [variants]; meaningless without them.
  final Set<int> matchedVariantIndices;

  /// Keep-if-null semantics: passing null keeps the current value. The
  /// pipeline never needs to reset a field back to null.
  ///
  /// [variants]/[matchedVariantIndices] are value-dependent: a copy that
  /// changes [value] must happen before the registry's variant step, not
  /// after (the pipeline seeds values on the pre-variant request).
  FieldBuildRequest copyWith({
    PresenceValue<dynamic>? value,
    SchemaWithContext? schemaSource,
    List<ValidationError>? errors,
    FieldResolveContext? resolveContext,
    String? title,
    bool? readOnly,
    bool? required,
    FieldAnnotations? fieldAnnotations,
    List<JsonFieldState>? variants,
    Set<int>? matchedVariantIndices,
  }) {
    return FieldBuildRequest(
      value: value ?? this.value,
      schemaSource: schemaSource ?? this.schemaSource,
      errors: errors ?? this.errors,
      resolveContext: resolveContext ?? this.resolveContext,
      title: title ?? this.title,
      readOnly: readOnly ?? this.readOnly,
      required: required ?? this.required,
      fieldAnnotations: fieldAnnotations ?? this.fieldAnnotations,
      variants: variants ?? this.variants,
      matchedVariantIndices: matchedVariantIndices ?? this.matchedVariantIndices,
    );
  }
}
