import 'package:form_foundation/form_foundation.dart';

import 'handlers/array/array_field_handler.dart';
import 'handlers/array/array_field_state.dart';
import 'handlers/bool/bool_field_handler.dart';
import 'handlers/bool/bool_field_state.dart';
import 'handlers/cycle/cycle_field_handler.dart';
import 'handlers/double/double_field_handler.dart';
import 'handlers/double/double_field_state.dart';
import 'handlers/enum/enum_field_handler.dart';
import 'handlers/enum/enum_field_state.dart';
import 'handlers/int/int_field_handler.dart';
import 'handlers/int/int_field_state.dart';
import 'handlers/null/null_field_handler.dart';
import 'handlers/null/null_field_state.dart';
import 'handlers/object/object_field_display_mode.dart';
import 'handlers/object/object_field_handler.dart';
import 'handlers/object/object_field_state.dart';
import 'handlers/raw/raw_field_handler.dart';
import 'handlers/raw/raw_field_state.dart';
import 'handlers/string/string_field_handler.dart';
import 'handlers/string/string_field_state.dart';
import 'handlers/unknown/unknown_field_handler.dart';
import 'models/cycle_field_state.dart';
import 'models/json_field_handler.dart';
import 'models/json_field_state.dart';
import 'models/json_handler_registration.dart';
import 'models/json_handler_registry.dart';
import 'models/schema_validation_mode.dart';
import 'models/type_based_json_handler_registry.dart';
import 'schema_resolver/schema_merger.dart';

/// Builds one handler for the standard registry. Receives the registry
/// getter (the registry does not exist yet while its handlers are being
/// constructed), so custom handlers close the handler ↔ registry cycle the
/// same way the built-in ones do.
typedef JsonFieldHandlerBuilder = JsonFieldHandler<JsonFieldState> Function(JsonHandlerRegistry Function() registryGetter);

/// The standard registry: every built-in handler wired in with its default
/// registration (see [JsonHandlerRegistration]), the lazy handler ↔ registry
/// cycle closed internally. This file is the package's composition root and
/// therefore sits at the `src/` root: it assembles the machinery that lives
/// in `models/` and the handlers that live in `handlers/`. Consumers configure common knobs via parameters
/// and replace whole registrations via [overrides] instead of assembling
/// ~10 constructors with `registryGetter: () => registry` by hand.
///
/// [overrides] is keyed by the registration's state type; an entry replaces
/// the built-in registration entirely — both the handler and its wiring
/// (claimed types, pickability) — so parameters of the replaced handler
/// (e.g. [displayMode] for the object one) do not apply to it.
/// [unknownFieldHandler] substitutes the fallback handler for values no
/// registered handler accepts (e.g. RawFieldHandler for a JSON text field).
JsonHandlerRegistry standardJsonHandlerRegistry({
  SchemaMerger? schemaMerger,
  ObjectFieldDisplayMode displayMode = ObjectFieldDisplayMode.all,
  bool arrayInline = false,
  bool objectInline = true,
  DataUrlFilePicker? filePicker,
  JsonFieldHandlerBuilder? unknownFieldHandler,
  Map<Type, JsonHandlerRegistrationBuilder> overrides = const {},
  SchemaValidationMode validationMode = SchemaValidationMode.strict,
}) {
  late final TypeBasedJsonHandlerRegistry registry;
  JsonHandlerRegistry registryGetter() => registry;

  JsonHandlerRegistration reg(Type stateType, JsonHandlerRegistrationBuilder defaultBuilder) => (overrides[stateType] ?? defaultBuilder)(registryGetter);

  final enumRegistration = reg(EnumFieldState, EnumFieldHandler.registration);

  return registry = TypeBasedJsonHandlerRegistry.fromRegistrations(
    validationMode: validationMode,
    schemaMerger: schemaMerger ?? SchemaMerger.withDefaults(),
    unknownFieldHandler: (unknownFieldHandler ?? (getter) => UnknownFieldHandler(registryGetter: getter))(registryGetter),
    enumFieldHandler: enumRegistration.handler,
    registrations: [
      reg(BoolFieldState, BoolFieldHandler.registration),
      reg(DoubleFieldState, DoubleFieldHandler.registration),
      reg(IntFieldState, IntFieldHandler.registration),
      reg(ArrayFieldState, (getter) => ArrayFieldHandler.registration(getter, inline: arrayInline)),
      reg(ObjectFieldState, (getter) => ObjectFieldHandler.registration(getter, displayMode: displayMode, inline: objectInline)),
      reg(NullFieldState, NullFieldHandler.registration),
      reg(StringFieldState, (getter) => StringFieldHandler.registration(getter, filePicker: filePicker)),
      enumRegistration,
      reg(RawFieldState, RawFieldHandler.registration),
      // Render-only dispatch for the states built by the registry's cycle
      // guard (recursive $ref cut-off); claims no types, not pickable.
      reg(CycleFieldState, CycleFieldHandler.registration),
    ],
  );
}
