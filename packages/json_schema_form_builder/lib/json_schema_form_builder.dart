/// The public facade of json_schema_form_builder.
///
/// Every export below is a deliberate, supported API; extending this list is
/// an API decision, not a convenience. Anything under `src/` that is not
/// exported here is internal with no stability guarantees: the package's own
/// tests may import such files directly, consumers must not.
library;

// ---------------------------------------------------------------------------
// Re-exports from form_foundation that appear in this package's API.
// ---------------------------------------------------------------------------
// Theming of the built-in field widgets.
export 'package:form_foundation/form_foundation.dart' show FormTheme, FormThemeData;
// Part of StringFieldHandler's public API (filePicker parameter).
export 'package:form_foundation/form_foundation.dart' show DataUrlFilePicker, PickedFileData;
// ---------------------------------------------------------------------------
// Re-exports from json_schema_builder that appear in this package's API:
// the parsed schema document (Schema.fromMap) and the validation error type.
// Basic integrations then need no direct json_schema_builder dependency;
// advanced schema work (ValidationContext, JsonType, ...) still imports it.
// ---------------------------------------------------------------------------
export 'package:json_schema_builder/json_schema_builder.dart' show Schema, ValidationError, ValidationErrorType;
// ---------------------------------------------------------------------------
// Built-in handlers and their states: constructed by hosts (directly or via
// standardJsonHandlerRegistry overrides) and matched against in custom code.
// ---------------------------------------------------------------------------
export 'package:json_schema_form_builder/src/handlers/array/array_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/array/array_field_state.dart';
export 'package:json_schema_form_builder/src/handlers/bool/bool_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/bool/bool_field_state.dart';
export 'package:json_schema_form_builder/src/handlers/cycle/cycle_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/double/double_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/double/double_field_state.dart';
export 'package:json_schema_form_builder/src/handlers/enum/enum_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/enum/enum_field_state.dart';
export 'package:json_schema_form_builder/src/handlers/int/int_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/int/int_field_state.dart';
export 'package:json_schema_form_builder/src/handlers/null/null_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/null/null_field_state.dart';
export 'package:json_schema_form_builder/src/handlers/object/object_field_display_mode.dart';
export 'package:json_schema_form_builder/src/handlers/object/object_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/object/object_field_state.dart';
// The raw JSON editing stack is public: hosts embed JsonEditor as a
// standalone editor (see the demo's Schema/JSON tabs) or reuse the
// highlighting in custom text fields; RawField is its form-field adapter.
export 'package:json_schema_form_builder/src/handlers/raw/json_editor.dart';
export 'package:json_schema_form_builder/src/handlers/raw/json_highlighter.dart';
export 'package:json_schema_form_builder/src/handlers/raw/raw_field.dart';
export 'package:json_schema_form_builder/src/handlers/raw/raw_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/raw/raw_field_state.dart';
export 'package:json_schema_form_builder/src/handlers/string/string_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/string/string_field_state.dart';
export 'package:json_schema_form_builder/src/handlers/unknown/unknown_field_handler.dart';
export 'package:json_schema_form_builder/src/handlers/unknown/unknown_field_state.dart';
// ---------------------------------------------------------------------------
// Localization: the UI strings of the built-in widgets, generated from ARB
// (bundled: en, pl, ru). Hosts register JsonFormLocalizations.localizationsDelegates
// for the bundled languages and extend JsonFormLocalizationsEn (plus
// JsonFormLocalizationsDelegate) for their own; without registration English
// is used.
// ---------------------------------------------------------------------------
export 'package:json_schema_form_builder/src/l10n/json_form_localizations.dart';
// ---------------------------------------------------------------------------
// The extension surface: everything a custom handler or a custom registry
// implements or receives.
// ---------------------------------------------------------------------------
export 'package:json_schema_form_builder/src/models/cycle_field_state.dart';
export 'package:json_schema_form_builder/src/models/field_build_request.dart';
export 'package:json_schema_form_builder/src/models/field_context.dart';
export 'package:json_schema_form_builder/src/models/json_field_handler.dart';
export 'package:json_schema_form_builder/src/models/json_field_renderer.dart';
export 'package:json_schema_form_builder/src/models/json_field_state.dart';
export 'package:json_schema_form_builder/src/models/json_field_state_builder.dart';
export 'package:json_schema_form_builder/src/models/json_handler_registration.dart';
export 'package:json_schema_form_builder/src/models/json_handler_registry.dart';
// The presence-aware value container used throughout the API.
export 'package:json_schema_form_builder/src/models/presence_value.dart';
// Validation policy while editing: the mode consumed by
// JsonHandlerRegistry/standardJsonHandlerRegistry, plus the marker that
// distinguishes "the validator rejected the schema" from data errors.
// validatorRejectedSchemaErrors (the error constructor) is internal.
export 'package:json_schema_form_builder/src/models/schema_validation_mode.dart'
    show SchemaValidationMode, SubmittableJsonFieldState, ValidatorRejectedSchemaFlag;
// Schema-prescribed values: const/single-enum pinning, seeds at document
// extension points, select-like option introspection, and the single write
// policy of representation switching (custom applyVariantSwitched overrides
// route through switchRepresentationValue).
export 'package:json_schema_form_builder/src/models/schema_values.dart'
    show EnumOption, schemaEnumOptions, schemaHasConst, schemaPinnedValue, schemaSeedValue, switchRepresentationValue;
export 'package:json_schema_form_builder/src/models/type_based_json_handler_registry.dart';
// Type reasoning shared by registries and handler admits-gates.
// synthesizedTypeBranchSchemas is internal.
export 'package:json_schema_form_builder/src/models/type_matching.dart' show dartTypeOfValue, isNullableSchema, jsonTypeOfValue, typesAcceptedBy;
// ---------------------------------------------------------------------------
// Registry assembly.
// ---------------------------------------------------------------------------
export 'package:json_schema_form_builder/src/schema_resolver/schema_merger.dart';
export 'package:json_schema_form_builder/src/standard_registry.dart';
// ---------------------------------------------------------------------------
// Host-side utilities.
// ---------------------------------------------------------------------------
// Keeps only the latest of overlapping async state rebuilds; the pattern a
// value-driven root needs (see the example app).
export 'package:json_schema_form_builder/src/utils/latest_request_guard.dart';
// valueAsString — display fallback for a value of an unexpected type;
// defaultMinInlineWidth — default of container handlers' minInlineWidth;
// validateDataBySchema — standalone validation with the same error surfacing
// the form uses. resolveOrder is internal.
export 'package:json_schema_form_builder/src/utils/utils.dart' show defaultMinInlineWidth, validateDataBySchema, valueAsString;
// Variant composition for custom handlers extending JsonFieldHandler.
export 'package:json_schema_form_builder/src/widgets/field_with_variants.dart';
// The turnkey schema -> live-validated form widget (see the example app);
// hosts needing more control assemble the pipeline it wraps by hand (demo).
export 'package:json_schema_form_builder/src/widgets/json_schema_form.dart';
