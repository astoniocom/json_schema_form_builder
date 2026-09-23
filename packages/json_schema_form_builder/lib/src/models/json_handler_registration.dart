import 'package:json_schema_builder/json_schema_builder.dart';

import 'json_field_handler.dart';
import 'json_field_state.dart';
import 'json_handler_registry.dart';

/// One entry of a type-based registry configuration (see
/// TypeBasedJsonHandlerRegistry.fromRegistrations): the handler instance plus
/// its wiring — the roles this registration assigns to the handler.
///
/// The wiring lives here, per registration, NOT on the handler class: which
/// handler is "the" editor for a JSON type is registry configuration (the
/// same handler class may occupy different roles in different registries),
/// while the handler itself carries only genuine capabilities
/// (JsonFieldStateBuilder.canEditValue). This is also why the raw JSON
/// handler no longer has to misdescribe itself: its registration claims no
/// types although the editor accepts any value.
///
/// Every built-in handler ships a static `registration` factory with its
/// default wiring, so registering one stays a single line (see
/// standardJsonHandlerRegistry).
class JsonHandlerRegistration {
  /// Creates a registration wiring [handler] into its roles.
  const JsonHandlerRegistration({
    required this.stateType,
    required this.handler,
    this.valueTypes = const [],
    this.schemaTypes = const [],
    this.pickableWithoutSchema = true,
  });

  /// The exact runtimeType of the states [handler] builds: the render-time
  /// dispatch key (handlerForField).
  final Type stateType;

  /// The handler occupying the roles this registration claims.
  final JsonFieldHandler<JsonFieldState> handler;

  /// Role claim: [handler] is the editor for values of these Dart types when
  /// JSON is edited without a schema (the dartTypeOfValue vocabulary). At
  /// most one registration may claim a given type.
  final List<Type> valueTypes;

  /// Role claim: [handler] is the editor for these JSON Schema types. At
  /// most one registration may claim a given type.
  final List<JsonType> schemaTypes;

  /// Whether "value type" pickers offer this handler when no schema
  /// constrains the type. False for handlers that cannot work without a
  /// schema (enum: there would be no values to pick from).
  final bool pickableWithoutSchema;
}

/// Builds a [JsonHandlerRegistration] given the getter that closes the lazy
/// handler ↔ registry cycle (the registry does not exist yet while its
/// handlers are being constructed).
typedef JsonHandlerRegistrationBuilder = JsonHandlerRegistration Function(JsonHandlerRegistry Function() registryGetter);
