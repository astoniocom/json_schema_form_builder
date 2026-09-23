import 'package:collection/collection.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../schema_resolver/schema_merger.dart';
import 'field_context.dart';
import 'json_field_handler.dart';
import 'json_field_state.dart';
import 'json_field_state_builder.dart';
import 'json_handler_registration.dart';
import 'json_handler_registry.dart';
import 'presence_value.dart';
import 'schema_validation_mode.dart';
import 'type_matching.dart';

/// Selection policy: enum keyword -> [enumFieldHandler], otherwise the JSON
/// Schema types claimed by the registrations
/// ([JsonHandlerRegistration.schemaTypes]), with a value-type based fallback
/// when the schema does not constrain the type.
///
/// All wiring (which handler occupies which role) comes in as explicit
/// configuration — see [JsonHandlerRegistration] and
/// [TypeBasedJsonHandlerRegistry.fromRegistrations]; handlers themselves
/// carry no selection data.
class TypeBasedJsonHandlerRegistry extends JsonHandlerRegistry {
  /// Creates a registry from explicit dispatch tables; most callers use
  /// [TypeBasedJsonHandlerRegistry.fromRegistrations] instead.
  // The initializers make defensive copies, so later mutations of the
  // caller's collections cannot change the dispatch tables.
  TypeBasedJsonHandlerRegistry({
    required Map<Type, JsonFieldHandler<JsonFieldState>> handlersByState,
    required Map<Type, JsonFieldHandler<JsonFieldState>> handlersByType,
    required Map<JsonType, JsonFieldHandler<JsonFieldState>> handlersBySchemaType,
    required List<JsonFieldHandler<JsonFieldState>> pickableWithoutSchema,
    required super.schemaMerger,
    required this.enumFieldHandler,
    required this.unknownFieldHandler,
    super.validationMode,
  }) : _handlersByState = Map.of(handlersByState),
       _handlersByType = Map.of(handlersByType),
       _handlersBySchemaType = Map.of(handlersBySchemaType),
       _pickableWithoutSchema = List.of(pickableWithoutSchema);

  /// Builds the dispatch maps from [registrations]. Each registration may
  /// claim a JSON Schema type, a value type and pickability; claims must not
  /// overlap (asserted).
  factory TypeBasedJsonHandlerRegistry.fromRegistrations({
    required List<JsonHandlerRegistration> registrations,
    required SchemaMerger schemaMerger,
    required JsonFieldHandler<JsonFieldState> unknownFieldHandler,
    required JsonFieldHandler<JsonFieldState> enumFieldHandler,
    SchemaValidationMode validationMode = SchemaValidationMode.strict,
  }) {
    final Map<Type, JsonFieldHandler<JsonFieldState>> handlersByState = {};
    final Map<Type, JsonFieldHandler<JsonFieldState>> handlersByType = {};
    final Map<JsonType, JsonFieldHandler<JsonFieldState>> handlersBySchemaType = {};
    final List<JsonFieldHandler<JsonFieldState>> pickableWithoutSchema = [];

    for (final registration in registrations) {
      assert(
        !handlersByState.containsKey(registration.stateType),
        'Duplicate registration for state type ${registration.stateType}.',
      );
      handlersByState[registration.stateType] = registration.handler;

      for (final type in registration.valueTypes) {
        assert(
          !handlersByType.containsKey(type),
          'Multiple registrations claim the value type $type: '
          '${handlersByType[type].runtimeType} and ${registration.handler.runtimeType}.',
        );
        handlersByType[type] = registration.handler;
      }
      for (final schemaType in registration.schemaTypes) {
        assert(
          !handlersBySchemaType.containsKey(schemaType),
          'Multiple registrations claim the JSON Schema type "${schemaType.typeName}": '
          '${handlersBySchemaType[schemaType].runtimeType} and ${registration.handler.runtimeType}.',
        );
        handlersBySchemaType[schemaType] = registration.handler;
      }
      if (registration.pickableWithoutSchema) {
        pickableWithoutSchema.add(registration.handler);
      }
    }

    return TypeBasedJsonHandlerRegistry(
      handlersByState: handlersByState,
      handlersByType: handlersByType,
      handlersBySchemaType: handlersBySchemaType,
      pickableWithoutSchema: pickableWithoutSchema,
      schemaMerger: schemaMerger,
      unknownFieldHandler: unknownFieldHandler,
      enumFieldHandler: enumFieldHandler,
      validationMode: validationMode,
    );
  }

  /// State runtimeType -> handler lookup: the render-time dispatch behind
  /// [handlerForField]. An implementation detail of this registry, not part
  /// of the [FieldHandlerRegistry] contract.
  final Map<Type, JsonFieldHandler<JsonFieldState>> _handlersByState;

  /// Value-type -> handler lookup. Used only when JSON is edited without a
  /// schema (or the schema does not constrain the type).
  final Map<Type, JsonFieldHandler<JsonFieldState>> _handlersByType;

  /// JSON Schema type -> handler lookup, built from
  /// [JsonHandlerRegistration.schemaTypes].
  final Map<JsonType, JsonFieldHandler<JsonFieldState>> _handlersBySchemaType;

  /// Handlers offered in "value type" pickers when no schema constrains the
  /// type, in registration order ([JsonHandlerRegistration.pickableWithoutSchema]).
  final List<JsonFieldHandler<JsonFieldState>> _pickableWithoutSchema;

  @override
  final JsonFieldHandler<JsonFieldState> unknownFieldHandler;

  /// The handler selected for every select-like schema (`enum`, or
  /// alternatives with pinned values), regardless of the value type.
  final JsonFieldHandler<JsonFieldState> enumFieldHandler;

  /// Looks up the handler by the exact runtimeType of the [field] state.
  ///
  /// Important: the match is strictly exact — a subtype of a registered type
  /// or a different parameterization of a generic type (Foo<int> vs
  /// Foo<dynamic>) will not be found and silently falls through to
  /// [unknownFieldHandler]. Register the concrete state types whose
  /// instances are actually created.
  @override
  JsonFieldHandler<JsonFieldState> handlerForField(JsonFieldState field) {
    return _handlersByState[field.runtimeType] ?? unknownFieldHandler;
  }

  /// Schema-constrained handlers when the schema constrains the type,
  /// otherwise the registrations that opted into schema-less picking
  /// ([JsonHandlerRegistration.pickableWithoutSchema], in registration
  /// order). That excludes keyword-selected handlers (enum: without a schema
  /// there are no values to pick from) and includes fallback editors (raw
  /// JSON).
  @override
  List<JsonFieldHandler<JsonFieldState>> pickableHandlers({
    required FieldResolveContext resolveContext,
    Schema? schema,
  }) {
    if (schema != null) {
      final constrained = handlersForSchema(schema: schema, resolveContext: resolveContext);
      if (constrained.isNotEmpty) return constrained;
    }
    return List.of(_pickableWithoutSchema);
  }

  /// For a schema admitting multiple types (type: ["string", "null"]) the
  /// candidate matching the value's type wins; for a schema that does not
  /// constrain the type the handler is looked up by the value type, same as
  /// when editing JSON without a schema.
  @override
  JsonFieldStateBuilder<JsonFieldState> stateBuilderFor({
    required Schema schema,
    required PresenceValue<dynamic>? value,
    required FieldResolveContext resolveContext,
  }) {
    final candidates = handlersForSchema(schema: schema, resolveContext: resolveContext);

    if (candidates.isEmpty) {
      if (value != null && value.present) {
        return stateBuilderForValue(value: value, resolveContext: resolveContext) ?? unknownFieldHandler;
      }
      return unknownFieldHandler;
    }

    // The null type never wins over the other admitted types: for the
    // nullable idiom (type: [X, "null"]) a null value is the cleared state
    // of the X editor (see JsonFieldHandler.normalizedEmptyValue), not a
    // switch to the null field — otherwise clearing a nullable string would
    // flip the field to the null editor with nothing left to type into.
    // The null handler is still reachable via type: "null" (a single
    // candidate).
    final nonNullCandidates = candidates.length > 1 ? candidates.where((h) => h != _handlersBySchemaType[JsonType.nil]).toList(growable: false) : candidates;
    final effective = nonNullCandidates.isNotEmpty ? nonNullCandidates : candidates;

    // An absent value carries no type information and must not influence the
    // choice (PresenceValue.absent().valueOrNull would be misread as JSON null).
    if (effective.length > 1 && value != null && value.present) {
      final valueType = jsonTypeOfValue(value.valueOrNull);
      final matched = valueType != null ? _handlersBySchemaType[valueType] : null;
      if (matched != null && effective.contains(matched)) return matched;
    }

    return effective.first;
  }

  @override
  JsonFieldStateBuilder<JsonFieldState>? stateBuilderForValue({
    required PresenceValue<dynamic> value,
    required FieldResolveContext resolveContext,
  }) {
    return handlersForType(dartTypeOfValue(value.valueOrNull), resolveContext).firstOrNull;
  }

  @override
  List<JsonFieldHandler<JsonFieldState>> handlersForSchema({
    required Schema schema,
    required FieldResolveContext resolveContext,
  }) {
    final enumValue = schema.enumValues;
    if (enumValue != null && enumValue.isNotEmpty) {
      return [enumFieldHandler];
    }

    return typesAcceptedBy(schema).map((t) => _handlersBySchemaType[t]).nonNulls.toSet().toList(growable: false);
  }

  /// The handler registered for the Dart value type [type], as an iterable
  /// (empty when none claimed it).
  Iterable<JsonFieldHandler<JsonFieldState>> handlersForType(Type type, FieldResolveContext resolveContext) {
    final handler = _handlersByType[type];
    return handler != null ? [handler] : [];
  }
}
