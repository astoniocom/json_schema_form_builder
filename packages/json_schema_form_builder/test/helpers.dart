/// Shared harnesses of the test suite: registry assembly, root-state
/// building the way production does it, and the array-form widget harness.
library;

import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:material_ui/material_ui.dart';

JsonHandlerRegistry buildRegistry({
  ObjectFieldDisplayMode displayMode = ObjectFieldDisplayMode.all,
  DataUrlFilePicker? filePicker,
  bool? inline,
}) {
  return standardJsonHandlerRegistry(
    displayMode: displayMode,
    filePicker: filePicker,
    arrayInline: inline ?? false,
    objectInline: inline ?? true,
  );
}

/// Builds a root state the way production code does: the schema is paired
/// with a ValidationContext created by withValidationContext.
Future<JsonFieldState?> buildRootState(
  JsonHandlerRegistry registry,
  Schema schema, {
  required PresenceValue<dynamic> value,
  String? title,
}) {
  return registry.withValidationContext(
    itemSchema: schema,
    rootSchema: schema,
    body: (validationContext) => registry.buildState(
      FieldBuildRequest(
        value: value,
        schemaSource: SchemaWithContext.maybe(schema, validationContext),
        title: title,
        resolveContext: FieldResolveContext(path: [], rootSchema: schema),
      ),
    ),
  );
}

/// Same as [buildRootState] but for the extension-point pipeline
/// (buildStateForNewField).
Future<JsonFieldState> buildNewFieldState(
  JsonHandlerRegistry registry,
  Schema schema, {
  required PresenceValue<dynamic> value,
  JsonFieldHandler<JsonFieldState>? handler,
}) {
  return registry.withValidationContext(
    itemSchema: schema,
    rootSchema: schema,
    body: (validationContext) => registry.buildStateForNewField(
      stateBuilder: handler,
      request: FieldBuildRequest(
        value: value,
        schemaSource: SchemaWithContext.maybe(schema, validationContext),
        resolveContext: FieldResolveContext(path: [], rootSchema: schema),
      ),
    ),
  );
}

Widget buildArrayForm(JsonHandlerRegistry registry, JsonFieldState state, void Function(JsonFieldState) onChanged) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Builder(
          builder: (context) => registry
              .handlerForField(state)
              .buildField(
                context: context,
                fieldState: state,
                displayContext: FieldDisplayContext.root(formState: state),
                onChanged: onChanged,
              ),
        ),
      ),
    ),
  );
}
