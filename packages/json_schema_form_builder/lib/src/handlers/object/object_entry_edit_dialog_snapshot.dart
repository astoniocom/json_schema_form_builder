import 'dart:async';

import 'package:collection/collection.dart';
import 'package:equatable/equatable.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/field_build_request.dart';
import '../../models/field_context.dart';
import '../../models/json_field_handler.dart';
import '../../models/json_field_state.dart';
import '../../models/json_field_state_builder.dart';
import '../../models/json_handler_registry.dart';
import '../../models/presence_value.dart';
import '../../models/schema_validation_mode.dart';
import '../../models/schema_values.dart';
import 'property_schemas.dart';

/// One option of the entry dialog's "Value type" picker: a handler paired
/// with the schema that admitted it (null when the handler comes from the
/// no-constraints fallback).
class FieldHandlerBinding extends Equatable {
  /// Creates a binding of [fieldHandler] to [schema].
  const FieldHandlerBinding({
    required this.fieldHandler,
    required this.schema,
  });

  /// The handler this option selects.
  final JsonFieldHandler fieldHandler;

  /// The schema that admitted [fieldHandler]; null for the fallback options
  /// offered when the key is unconstrained.
  final Schema? schema;

  @override
  List<Object?> get props => [fieldHandler, schema];
}

/// The derived, immutable model behind ObjectEntryEditDialog: everything the
/// dialog shows for the current key — the admissible handlers, the selected
/// one, the value editor's state and the schemas to validate against.
/// Rebuilt (via [build]/[applyHandler]/[applyFieldState]) instead of
/// mutated; Equatable so an unchanged snapshot skips the setState.
class EntryEditorSnapshot extends Equatable {
  /// Creates a snapshot; use [build] to compute one from the dialog inputs.
  const EntryEditorSnapshot({
    required this.selectedHandler,
    required this.key,
    this.schemasForKey = const [],
    this.availableHandlers = const [],
    this.schemasToValidate = const [],
    this.fieldState,
    this.validationMode = SchemaValidationMode.strict,
  });

  /// The schemas applying to [key] (`properties`, `patternProperties`,
  /// a schema-valued `additionalProperties`).
  final List<Schema> schemasForKey;

  /// Field types/handlers admissible for [key].
  final List<FieldHandlerBinding> availableHandlers;

  /// The currently selected "Value type" option.
  final FieldHandlerBinding selectedHandler;

  /// The subset of [schemasForKey] the current value must satisfy (schemas
  /// admitting the selected handler, plus unconstrained ones).
  final List<Schema> schemasToValidate;

  /// The state of the value editor; null while the first build is in flight.
  final JsonFieldState? fieldState;

  /// The property key the snapshot was computed for.
  final String key;

  /// Captured from the registry at [build] time: [applyFieldState] has no
  /// registry argument, so the snapshot carries the mode itself.
  final SchemaValidationMode validationMode;

  /// [validateValue] honoring [mode]: under [SchemaValidationMode.none] the
  /// result is empty without running the validator, so applyErrors marks the
  /// state "validated clean" and submission is never blocked.
  static Future<List<ValidationError>> _validateUnderMode({
    required List<Schema> schemasToValidate,
    required dynamic value,
    required SchemaValidationMode mode,
  }) async {
    if (mode == SchemaValidationMode.none) return const [];
    return validateValue(schemasToValidate: schemasToValidate, value: value);
  }

  /// A copy with the given parts replaced ([fieldState] uses presence
  /// semantics: absent keeps, present-null clears).
  EntryEditorSnapshot copyWith({
    List<Schema>? schemasForKey,
    List<FieldHandlerBinding>? availableHandlers,
    FieldHandlerBinding? selectedHandler,
    List<Schema>? schemasToValidate,
    PresenceValue<JsonFieldState?>? fieldState,
    String? key,
  }) {
    return EntryEditorSnapshot(
      schemasForKey: schemasForKey ?? this.schemasForKey,
      availableHandlers: availableHandlers ?? this.availableHandlers,
      selectedHandler: selectedHandler ?? this.selectedHandler,
      schemasToValidate: schemasToValidate ?? this.schemasToValidate,
      fieldState: fieldState != null ? fieldState.valueOrNull : this.fieldState,
      key: key ?? this.key,
      validationMode: validationMode,
    );
  }

  /// Computes the snapshot for [key]: resolves the admissible handlers,
  /// keeps (or re-selects) the handler, builds/revalidates the value state.
  /// Null when no handler is admissible (the key is fully forbidden).
  static Future<EntryEditorSnapshot?> build({
    required ObjectSchema? schema,
    required String key,
    required FieldDisplayContext displayContext,
    required JsonHandlerRegistry handlerRegistry,
    required bool additionalPropertiesAllowed,
    required Map<RegExp, Schema> fieldNamePatterns,
    JsonFieldState? initialState,
    EntryEditorSnapshot? previousSnapshot,
  }) async {
    final List<Schema> schemasForKey = schema != null ? computeSchemasForKey(schema, key, fieldNamePatterns) : const [];

    final childDisplayContext = displayContext.child(key);

    final handlerToSchemaMap = _resolveAvailableHandlers(
      handlerRegistry: handlerRegistry,
      schemasForKey: schemasForKey,
      additionalPropertiesAllowed: additionalPropertiesAllowed,
      childDisplayContext: childDisplayContext,
    );

    final availableHandlers = handlerToSchemaMap.entries
        .map((mapEntry) => FieldHandlerBinding(fieldHandler: mapEntry.key, schema: mapEntry.value))
        .toList(growable: false);

    final selectedHandler = _resolveSelectedHandler(
      availableHandlers: availableHandlers,
      handlerToSchemaMap: handlerToSchemaMap,
      initialState: initialState,
      previousHandler: previousSnapshot?.selectedHandler.fieldHandler,
    );
    if (selectedHandler == null) return null;

    final schemasToValidate = _getSchemasToValidate(
      key: key,
      availableSchemas: schemasForKey,
      selectedHandler: selectedHandler.fieldHandler,
      displayContext: displayContext,
      handlerRegistry: handlerRegistry,
    );
    final title = selectedHandler.schema?.title;

    final validationMode = handlerRegistry.validationMode;
    final JsonFieldState? fieldState;
    final List<ValidationError> valueErrors;

    if (previousSnapshot == null && initialState != null) {
      valueErrors = await _validateUnderMode(schemasToValidate: schemasToValidate, value: initialState.valueOrNull, mode: validationMode);

      // The freshly computed errors are applied to the initial state too:
      // otherwise an existing entry keeps its stale errors (possibly null),
      // which blocks submitting the dialog without editing the value first.
      fieldState = initialState.applyErrors(valueErrors);
    } else {
      final builtState = await _buildStateForHandler(
        handler: selectedHandler,
        currentValue: previousSnapshot?.fieldState?.valueOrNull,
        title: title,
        childDisplayContext: childDisplayContext,
        handlerRegistry: handlerRegistry,
      );

      valueErrors = await _validateUnderMode(schemasToValidate: schemasToValidate, value: builtState.valueOrNull, mode: validationMode);
      fieldState = builtState.applyErrors(valueErrors);
    }

    return EntryEditorSnapshot(
      schemasForKey: schemasForKey,
      availableHandlers: availableHandlers,
      selectedHandler: selectedHandler,
      schemasToValidate: schemasToValidate,
      fieldState: fieldState,
      key: key,
      validationMode: validationMode,
    );
  }

  @override
  List<Object?> get props => [
    schemasForKey,
    availableHandlers,
    selectedHandler,
    schemasToValidate,
    fieldState,
    key,
    validationMode,
  ];

  /// This snapshot with the value editor's [state] stored and revalidated.
  Future<EntryEditorSnapshot> applyFieldState(JsonFieldState? state) async {
    final fieldErrors = await _validateUnderMode(
      schemasToValidate: schemasToValidate,
      value: state?.valueOrNull,
      mode: validationMode,
    );

    return copyWith(
      fieldState: PresenceValue(state?.applyErrors(fieldErrors)),
    );
  }

  /// This snapshot with the "Value type" switched to [handler]: the value is
  /// carried over/reseeded (see switchRepresentationValue) and revalidated.
  Future<EntryEditorSnapshot> applyHandler({
    required FieldHandlerBinding handler,
    required FieldDisplayContext displayContext,
    required JsonHandlerRegistry handlerRegistry,
  }) async {
    final schemasToValidate = _getSchemasToValidate(
      key: key,
      availableSchemas: schemasForKey,
      selectedHandler: handler.fieldHandler,
      displayContext: displayContext,
      handlerRegistry: handlerRegistry,
    );

    final childDisplayContext = displayContext.child(key);

    final newFieldState = await _buildStateForHandler(
      handler: handler,
      currentValue: fieldState?.valueOrNull,
      title: handler.schema?.title,
      childDisplayContext: childDisplayContext,
      handlerRegistry: handlerRegistry,
    );

    final valueErrors = await _validateUnderMode(schemasToValidate: schemasToValidate, value: newFieldState.valueOrNull, mode: validationMode);

    return copyWith(
      selectedHandler: handler,
      schemasToValidate: schemasToValidate,
      fieldState: PresenceValue(newFieldState.applyErrors(valueErrors)),
    );
  }

  /// Builds the state for [handler] from the value produced by the shared
  /// switch-representation policy ([switchRepresentationValue]): the current
  /// value narrowed to the handler's supported types, the schema
  /// `const`/`default` seed (the dialog extends the JSON document), then the
  /// handler's [JsonFieldStateBuilder.canonicalEmptyValue] ([] / {} / '') —
  /// without it, submitting e.g. an untouched array would put null into the
  /// document instead of []. Scalars without a canonical empty value
  /// (number, bool, null) keep the empty value as is.
  static Future<JsonFieldState> _buildStateForHandler({
    required FieldHandlerBinding handler,
    required Object? currentValue,
    required String? title,
    required FieldDisplayContext childDisplayContext,
    required JsonHandlerRegistry handlerRegistry,
  }) async {
    // Only the domain half of the binding's handler is needed here: this
    // path builds state and never renders.
    final JsonFieldStateBuilder<JsonFieldState> builder = handler.fieldHandler;

    // canEditValue implementations normalize the runtime type (e.g.
    // List<int> -> List<dynamic>), so a value with a specialized generic
    // type is not dropped by mistake.
    bool admits(Object? value) => value == null || builder.canEditValue(value);

    final seededValue = switchRepresentationValue(
      targetSchema: handler.schema,
      currentValue: currentValue != null && admits(currentValue) ? PresenceValue<dynamic>(currentValue) : const PresenceValue<dynamic>.absent(),
      admits: admits,
      emptySeed: builder.canonicalEmptyValue,
      rootSchema: childDisplayContext.rootSchema,
    );

    return handlerRegistry.withValidationContext(
      itemSchema: handler.schema,
      rootSchema: childDisplayContext.rootSchema,
      body: (validationContext) => handlerRegistry.buildStateForNewField(
        stateBuilder: builder,
        request: FieldBuildRequest(
          value: seededValue,
          schemaSource: SchemaWithContext.maybe(handler.schema, validationContext),
          title: title,
          resolveContext: childDisplayContext,
        ),
      ),
    );
  }

  /// Builds the list of schemas against which values for the key [key]
  /// must be validated.
  static List<Schema> _getSchemasToValidate({
    required String key,
    required List<Schema> availableSchemas,
    required JsonFieldHandler selectedHandler,
    required JsonHandlerRegistry handlerRegistry,
    required FieldDisplayContext displayContext,
  }) {
    return availableSchemas
        .where((schema) {
          final handlers = handlerRegistry.handlersForSchema(schema: schema, resolveContext: displayContext.child(key));
          // A schema that does not constrain the type applies to any handler.
          return handlers.isEmpty || handlers.contains(selectedHandler);
        })
        .toList(growable: false);
  }

  static FieldHandlerBinding? _resolveSelectedHandler({
    required Map<JsonFieldHandler, Schema?> handlerToSchemaMap,
    required List<FieldHandlerBinding> availableHandlers,
    required JsonFieldHandler? previousHandler,
    required JsonFieldState? initialState,
  }) {
    return previousHandler != null && handlerToSchemaMap.containsKey(previousHandler)
        ? FieldHandlerBinding(fieldHandler: previousHandler, schema: handlerToSchemaMap[previousHandler])
        : (initialState != null
              ? availableHandlers.firstWhereOrNull((handlerBinding) => handlerBinding.fieldHandler.matchesState(initialState)) ?? availableHandlers.firstOrNull
              : availableHandlers.firstOrNull);
  }

  static Map<JsonFieldHandler, Schema?> _resolveAvailableHandlers({
    required JsonHandlerRegistry handlerRegistry,
    required List<Schema> schemasForKey,
    required bool additionalPropertiesAllowed,
    required FieldDisplayContext childDisplayContext,
  }) {
    final Map<JsonFieldHandler, Schema?> handlerToSchemaMap = {};

    for (final appropriateSchema in schemasForKey) {
      // A schema that does not constrain the type admits any handler; that
      // fallback is the registry's pickableHandlers policy.
      final handlers = handlerRegistry.pickableHandlers(schema: appropriateSchema, resolveContext: childDisplayContext);
      for (final handler in handlers) {
        handlerToSchemaMap[handler] = appropriateSchema;
      }
    }

    // schemasForKey.isEmpty means not only "the key is not described in properties/patternProperties",
    // but also "additionalProperties does not narrow the type" (true rather than a concrete schema) —
    // computeSchemasForKey returns a non-empty list if additionalProperties specifies a schema.
    // So the fallback to the whole handler registry applies only when there are no constraints at all.
    if (additionalPropertiesAllowed && schemasForKey.isEmpty) {
      for (final handler in handlerRegistry.pickableHandlers(resolveContext: childDisplayContext)) {
        if (!handlerToSchemaMap.containsKey(handler)) {
          handlerToSchemaMap[handler] = null;
        }
      }
    }

    return handlerToSchemaMap;
  }
}
