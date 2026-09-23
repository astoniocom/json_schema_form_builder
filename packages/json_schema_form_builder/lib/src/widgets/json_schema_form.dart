import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../models/field_build_request.dart';
import '../models/field_context.dart';
import '../models/json_field_state.dart';
import '../models/json_handler_registry.dart';
import '../models/presence_value.dart';
import '../models/schema_validation_mode.dart';
import '../standard_registry.dart';
import '../utils/latest_request_guard.dart';
import '../utils/utils.dart';

/// The turnkey form: renders an editor tree generated from [schema],
/// starting at [initialValue].
///
/// This widget owns the state-building pipeline a host would otherwise
/// assemble by hand — registry, `withValidationContext` +
/// `buildState(FieldBuildRequest(...))`, dispatch via `handlerForField`, and
/// a [LatestRequestGuard] against overlapping async rebuilds. Hosts that
/// need more control (external value updates, custom error routing) use that
/// pipeline directly; the demo app is the reference for it.
///
/// The value is uncontrolled: [initialValue] seeds the form, edits flow out
/// through [onChanged]. To reset from outside, pass a new [Key]. Replacing
/// [schema] rebuilds the form and keeps the current value.
///
/// Validation timing follows the Form/AutovalidateMode convention: with
/// [validateOnChange] (the default) every change is validated; without it
/// the host triggers validation explicitly —
///
/// ```dart
/// final formKey = GlobalKey<JsonSchemaFormState>();
/// JsonSchemaForm(key: formKey, schema: schema, validateOnChange: false, ...)
/// ...
/// final valid = await formKey.currentState!.validate();
/// ```
class JsonSchemaForm extends StatefulWidget {
  /// Creates a form; a null [registry] uses standardJsonHandlerRegistry().
  const JsonSchemaForm({
    this.schema,
    this.initialValue = const PresenceValue.absent(),
    this.registry,
    this.onChanged,
    this.validateOnChange = true,
    super.key,
  });

  /// The schema the form is generated from; null edits schema-less JSON
  /// (fields are inferred from the value).
  final Schema? schema;

  /// The value the form starts with; `PresenceValue.absent()` starts empty
  /// (schema `default`s still seed their fields).
  final PresenceValue<dynamic> initialValue;

  /// The handler registry; defaults to [standardJsonHandlerRegistry] with its
  /// default wiring. Pass a configured one for custom handlers, a file
  /// picker, or a different `SchemaValidationMode` for the edit dialogs.
  final JsonHandlerRegistry? registry;

  /// Called with the rebuilt root state after every applied change — the
  /// initial build included, so validity gates (e.g. a Submit button checking
  /// `state.isValid`) are correct before the first edit. Read the current
  /// value from `state.value`.
  final void Function(JsonFieldState<Schema> state)? onChanged;

  /// When true (the default) every change is validated and the errors are
  /// shown inline as the user types. When false, rebuilds skip validation
  /// (a previous verdict is dropped on the next edit, mirroring the
  /// on-demand convention) and the host runs it explicitly through
  /// [JsonSchemaFormState.validate]. Note that an unvalidated state reports
  /// `isValid == false`: gate submission on [JsonSchemaFormState.validate],
  /// not on `state.isValid`, in this mode.
  final bool validateOnChange;

  @override
  State<JsonSchemaForm> createState() => JsonSchemaFormState();
}

/// The state of a [JsonSchemaForm]; reached with a
/// `GlobalKey<JsonSchemaFormState>` to trigger [validate], the same pattern
/// as Flutter's `Form`/`FormState`.
class JsonSchemaFormState extends State<JsonSchemaForm> {
  late JsonHandlerRegistry _registry = widget.registry ?? standardJsonHandlerRegistry();
  JsonFieldState<Schema>? _formState;
  late final LatestRequestGuard _rebuildGuard = LatestRequestGuard(isAlive: () => mounted);

  @override
  void initState() {
    super.initState();
    // The guard applies (or discards) the result itself; there is nothing to
    // await at the call sites (initState/didUpdateWidget cannot await anyway).
    unawaited(_rebuild(widget.initialValue));
  }

  @override
  void didUpdateWidget(covariant JsonSchemaForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final registryReplaced = widget.registry != oldWidget.registry;
    if (registryReplaced) {
      _registry = widget.registry ?? standardJsonHandlerRegistry();
    }
    if (registryReplaced || widget.schema != oldWidget.schema) {
      unawaited(_rebuild(_formState?.value ?? widget.initialValue));
    }
  }

  /// Validates the current value and applies the errors to the form; returns
  /// whether the value may be submitted. The counterpart of
  /// `FormState.validate` for hosts that set [JsonSchemaForm.validateOnChange]
  /// to false (with live validation it is not needed — the reported states
  /// already carry the verdict).
  ///
  /// The verdict follows the registry's `SchemaValidationMode`
  /// ([SubmittableJsonFieldState.isSubmittable]) — the same gate the edit
  /// dialogs' OK buttons use, so a schema the validator cannot process
  /// blocks the form only under the strict mode.
  ///
  /// Returns true when there is no [JsonSchemaForm.schema]: schema-less
  /// editing has nothing to validate against.
  Future<bool> validate() async {
    await _rebuild(_formState?.value ?? widget.initialValue, validate: true);
    if (widget.schema == null) return true;
    return _formState?.isSubmittable(_registry.validationMode) ?? false;
  }

  /// Builds the root state for [value] — validated against the schema when
  /// [validate] (defaulting to [JsonSchemaForm.validateOnChange]) says so —
  /// and lets the registry pick and configure a handler for every field.
  ///
  /// The returned future completes when the resulting state has been applied
  /// (or discarded in favor of a newer rebuild).
  Future<void> _rebuild(PresenceValue<dynamic> value, {bool? validate}) {
    final schema = widget.schema;
    final registry = _registry;
    final shouldValidate = validate ?? widget.validateOnChange;
    return _rebuildGuard.run(
      () async {
        final errors = shouldValidate ? await validateDataBySchema(schema, value.valueOrNull) : null;
        return registry.withValidationContext(
          itemSchema: schema,
          rootSchema: null,
          // OrUndefined: even a value no handler admits must render (as the
          // fallback field) instead of leaving the form blank.
          body: (validationContext) => registry.buildStateOrUndefined(
            FieldBuildRequest(
              value: value,
              schemaSource: SchemaWithContext.maybe(schema, validationContext),
              title: schema?.title,
              errors: errors,
              resolveContext: FieldResolveContext(path: [], rootSchema: schema),
            ),
          ),
        );
      },
      (newState) {
        setState(() => _formState = newState);
        widget.onChanged?.call(newState);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = _formState;
    // The first state is still being built (single async hop, no I/O): a
    // spinner would only flash, so render nothing.
    if (formState == null) return const SizedBox.shrink();

    return _registry.handlerForField(formState).buildField(
      context: context,
      fieldState: formState,
      displayContext: FieldDisplayContext.root(formState: formState),
      onChanged: (newState) => unawaited(_rebuild(newState.value)),
    );
  }
}
