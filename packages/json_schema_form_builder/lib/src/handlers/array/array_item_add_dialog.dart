import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_context.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registry.dart';
import '../../models/schema_validation_mode.dart';
import '../../utils/latest_request_guard.dart';

/// Dialog to enter a new array item's value before the item is appended to
/// the list, so a bare null is never added silently. Returns the entered
/// [JsonFieldState] or null when cancelled.
class ArrayItemAddDialog extends StatefulWidget {
  /// Creates the dialog around the pre-built [initialState].
  const ArrayItemAddDialog({
    required this.initialState,
    required this.handlerRegistry,
    required this.displayContext,
    this.itemSchema,
    this.rootSchema,
    super.key,
  });

  /// The new item's state as pre-built by the add flow (seeded value,
  /// resolved schema); the dialog edits it in place.
  final JsonFieldState initialState;

  /// The registry the item editor is rendered and validated through.
  final JsonHandlerRegistry handlerRegistry;

  /// The context of the new item, dialog path already reset.
  final FieldDisplayContext displayContext;

  /// Validates the entered value; null admits any value.
  final Schema? itemSchema;

  /// Root document schema; needed to resolve `$ref`s of [itemSchema] that
  /// point into the root (e.g. `#/definitions/...`) during validation.
  final Schema? rootSchema;

  @override
  State<ArrayItemAddDialog> createState() => _ArrayItemAddDialogState();
}

class _ArrayItemAddDialogState extends State<ArrayItemAddDialog> {
  /// The initial state may be unvalidated (errors == null), so the OK button
  /// stays disabled until the first validation completes and applyErrors
  /// marks the state validated (see [JsonFieldState.errors]).
  late JsonFieldState _fieldState = widget.initialState;

  late final LatestRequestGuard _validationGuard = LatestRequestGuard(isAlive: () => mounted);

  @override
  void initState() {
    super.initState();
    unawaited(_applyState(widget.initialState));
  }

  Future<void> _applyState(JsonFieldState state) {
    return _validationGuard.run(
      () async {
        final errors = await widget.handlerRegistry.validateValue(
          itemSchema: widget.itemSchema,
          rootSchema: widget.rootSchema,
          value: state.valueOrNull,
        );
        return state.applyErrors(errors);
      },
      (result) => setState(() => _fieldState = result),
    );
  }

  /// Which errors block is the registry's validation mode's decision (a
  /// validator-rejected schema does not block under lenient/none).
  bool get _canSubmit => _fieldState.isSubmittable(widget.handlerRegistry.validationMode);

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    return FormDialog(
      title: Text(jsonFormLocalizationsOf(context).addItemDialogTitle),
      onClose: () => Navigator.pop(context),
      // The width policy (min(480, available), content-independent) lives in
      // FormDialog.contentMaxWidth.
      content: SingleChildScrollView(
        child: widget.handlerRegistry
            .handlerForField(_fieldState)
            .buildField(
              context: context,
              fieldState: _fieldState,
              displayContext: widget.displayContext,
              onChanged: _applyState,
            ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _canSubmit ? () => Navigator.pop(context, _fieldState) : null,
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }
}
