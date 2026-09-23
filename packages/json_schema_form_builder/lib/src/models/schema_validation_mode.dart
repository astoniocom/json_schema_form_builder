import 'package:json_schema_builder/json_schema_builder.dart';

import 'json_field_state.dart';

/// How the library validates values while they are edited (the entry edit
/// dialog, the array item add dialog, JsonHandlerRegistry.validateValue).
///
/// The distinction matters when the schema uses features the underlying
/// validator (package json_schema_builder) cannot process: validation then
/// fails with an exception rather than a verdict about the data. Such a
/// failure is reported as a [ValidationError] marked with
/// [ValidatorRejectedSchemaFlag.isValidatorRejectedSchema]; whether it blocks
/// submission is this mode's decision.
enum SchemaValidationMode {
  /// No validation while editing: nothing is reported and submission is
  /// never blocked by value validation.
  none,

  /// Validation runs; data errors are reported and block submission, but a
  /// schema the validator cannot process is only reported without blocking —
  /// a value that could not be checked is not evidence of a wrong value.
  lenient,

  /// Validation runs; both data errors and a validator-rejected schema block
  /// submission: an unchecked value is treated as unsafe to submit.
  strict,
}

/// The marker key stored in the [ValidationError] map representation.
/// [ValidationError] is an extension type over `Map<String, Object?>`, so a
/// subclass marker is impossible; an extra map key survives every copy the
/// validator API makes.
const String _validatorRejectedSchemaKey = 'validatorRejectedSchema';

/// The single "validator rejected the schema" error list: the shared policy
/// of every validation entry point (validateDataBySchema,
/// JsonHandlerRegistry.validateValue, the entry dialog's multi-schema
/// validation) — a schema the validator cannot process surfaces as a visible
/// error instead of an exception.
///
/// The message names the actual source (the json_schema_builder validator,
/// not this library or the user's data) and carries the validator's
/// [exception], so the unsupported schema feature is identifiable and
/// reportable upstream. English on purpose: validation runs without a
/// BuildContext, and every other validator message is English too.
///
/// The produced error is marked (see
/// [ValidatorRejectedSchemaFlag.isValidatorRejectedSchema]) so that
/// [SchemaValidationMode.lenient] can report it without blocking submission.
List<ValidationError> validatorRejectedSchemaErrors(Object exception) => [
  ValidationError.fromMap({
    'error': ValidationErrorType.custom.name,
    'path': const <String>[],
    'details':
        'This schema uses features the JSON Schema validator '
        '(package json_schema_builder) cannot process; the value was left '
        'unvalidated. Validator error: $exception',
    _validatorRejectedSchemaKey: true,
  }),
];

/// Detection of the sentinel error produced by [validatorRejectedSchemaErrors].
extension ValidatorRejectedSchemaFlag on ValidationError {
  /// True for the error produced by [validatorRejectedSchemaErrors]: the
  /// validator could not process the schema and the value was left
  /// unvalidated. The error describes the schema/validator pair, not the
  /// data, which is why [SchemaValidationMode.lenient] shows it without
  /// blocking submission.
  bool get isValidatorRejectedSchema => (this as Map<String, Object?>)[_validatorRejectedSchemaKey] == true;
}

/// The submission gate: whether a state passes under a [SchemaValidationMode].
extension SubmittableJsonFieldState on JsonFieldState {
  /// Whether submission gates (the dialogs' OK buttons) accept this state
  /// under [mode]: validated and free of blocking errors. Under
  /// [SchemaValidationMode.strict] every error blocks (equivalent to
  /// [JsonFieldState.isValid]); under [SchemaValidationMode.lenient] a
  /// validator-rejected schema does not. Under [SchemaValidationMode.none]
  /// validation is skipped, so a validated state is clean by construction —
  /// the lenient rule returns the same result.
  bool isSubmittable(SchemaValidationMode mode) {
    final errors = this.errors;
    if (errors == null) return false; // Not validated yet.
    return switch (mode) {
      SchemaValidationMode.strict => errors.isEmpty,
      SchemaValidationMode.none || SchemaValidationMode.lenient => errors.every((e) => e.isValidatorRejectedSchema),
    };
  }
}
