import 'dart:async';

import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:material_ui/material_ui.dart';

import '../l10n/json_form_localizations.dart';
import '../models/field_context.dart';
import '../models/json_field_renderer.dart';
import '../models/json_field_state.dart';
import '../models/json_handler_registry.dart';
import '../models/schema_validation_mode.dart';

/// The dialog editing one field (a collapsed object/array opens here): the
/// field's editor at dialog-root presentation, an OK button gated by the
/// registry's validation mode. Pops with the edited state on OK, null on
/// cancel.
class FieldEditorScreen extends StatefulWidget {
  /// Creates the dialog editing [initState].
  const FieldEditorScreen({
    required this.initState,
    required this.registry,
    required this.displayContext,
    required this.fieldTitle,
    this.validateOnChange = true,
    super.key,
  });

  /// The state to edit; the dialog works on a local copy until OK.
  final JsonFieldState<Schema> initState;

  /// The registry the editor is rendered and validated through.
  final JsonHandlerRegistry registry;

  /// Whether edits are validated as they happen; the OK gate validates
  /// regardless.
  final bool validateOnChange;

  /// The context of the field being edited; the dialog resets its display
  /// scope (see FieldDisplayContext.resetDisplay).
  final FieldDisplayContext displayContext;

  /// The dialog title.
  final String fieldTitle;

  @override
  State<FieldEditorScreen> createState() => _FieldEditorScreenState();
}

class _FieldEditorScreenState extends State<FieldEditorScreen> {
  late JsonFieldState<Schema> _formState = widget.initState;

  @override
  void initState() {
    super.initState();

    if (widget.validateOnChange) {
      unawaited(_checkBlocked());
    }
  }

  /// Validates the current value, applies the result to the state and
  /// returns whether submission is blocked. Goes through
  /// [JsonHandlerRegistry.validateValue], so it shares the form's whole
  /// validation policy: a schema the validator cannot process surfaces as a
  /// marked error instead of an unhandled exception, and the registry's
  /// [SchemaValidationMode] decides both whether validation runs at all and
  /// whether such an error blocks the OK button.
  Future<bool> _checkBlocked() async {
    final curVal = _formState.valueOrNull;
    if (!_formState.hasValue) return false;

    final errors = await widget.registry.validateValue(
      itemSchema: widget.initState.schema,
      rootSchema: _formState.rootSchema,
      value: curVal,
    );

    final newState = _formState.applyErrors(errors);
    setState(() => _formState = newState);
    return !newState.isSubmittable(widget.registry.validationMode);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    // Only the presentation half is needed: this screen renders and lets the
    // widget mutate the state through onChanged, it never builds states.
    final JsonFieldRenderer<JsonFieldState> fieldHandler = widget.registry.handlerForField(_formState);

    return FormDialog(
      title: Text(jsonFormLocalizationsOf(context).editDialogTitle(widget.fieldTitle)),
      content: SingleChildScrollView(
        child: fieldHandler.buildField(
          context: context,
          fieldState: _formState,
          displayContext: widget.displayContext.resetDisplay(),
          onChanged: (newState) {
            setState(() {
              _formState = newState;
            });

            if (widget.validateOnChange) {
              unawaited(_checkBlocked());
            }
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: Navigator.of(context).pop,
          child: Text(localizations.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _formState != widget.initState && _formState.hasValue
              ? () async {
                  final blocked = await _checkBlocked();
                  if (blocked || !context.mounted) return;

                  Navigator.of(context).pop(_formState);
                }
              : null,
          // onLongPress: () {
          //   Navigator.of(context).pop(_formState);
          // },
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }
}
