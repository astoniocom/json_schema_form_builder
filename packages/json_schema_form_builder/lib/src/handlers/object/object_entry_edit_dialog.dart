import 'dart:async';

import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_context.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registry.dart';
import '../../models/schema_validation_mode.dart';
import '../../utils/latest_request_guard.dart';
import 'object_entry_edit_dialog_snapshot.dart';
import 'property_schemas.dart';

/// The dialog adding or editing one object property: a key field (validated
/// against duplicates and, for additional properties, against the schema's
/// naming rules) and the value editor the key's schema selects. Pops with a
/// `(key, state)` record on OK.
class ObjectEntryEditDialog extends StatefulWidget {
  /// Creates the dialog; providing [existingKey]/[existingState] switches it
  /// from "add" to "edit".
  const ObjectEntryEditDialog({
    required this.handlerRegistry,
    required this.displayContext,
    required this.fieldNamePatterns,
    this.forbiddenKeys = const {},
    this.existingKey,
    this.existingState,
    this.schema,
    this.keyReadOnly = false,
    this.requireExplicitAdditionalProperties = true,
    super.key,
  });

  /// The key being edited; null when adding a new property.
  final String? existingKey;

  /// The state being edited; null when adding a new property.
  final JsonFieldState? existingState;

  /// Keys already taken by the object's other properties.
  final Set<String> forbiddenKeys;

  /// When true, the key field is read-only (e.g. for schema-defined fields).
  final bool keyReadOnly;

  /// The registry the value editor is built and rendered through.
  final JsonHandlerRegistry handlerRegistry;

  /// The owning object's schema; drives the key's schema lookup
  /// (`properties`, `patternProperties`, `additionalProperties`).
  final ObjectSchema? schema;

  /// Where the owning object sits (dialog depth, header visibility).
  final FieldDisplayContext displayContext;

  /// See ObjectFieldHandler.requireExplicitAdditionalProperties.
  final bool requireExplicitAdditionalProperties;

  /// The owning object's compiled `patternProperties` (see
  /// ObjectFieldState.fieldNamePatterns).
  final Map<RegExp, Schema> fieldNamePatterns;

  @override
  State<ObjectEntryEditDialog> createState() => _ObjectEntryEditDialogState();
}

class _ObjectEntryEditDialogState extends State<ObjectEntryEditDialog> {
  late final TextEditingController _keyController;
  String? _keyError;

  EntryEditorSnapshot? _snapshot;

  late final LatestRequestGuard _snapshotGuard = LatestRequestGuard(isAlive: () => mounted);

  bool get _additionalPropertiesAllowed => resolveAdditionalPropertiesAllowed(
    widget.schema,
    treatUnspecifiedAsForbidden: widget.requireExplicitAdditionalProperties,
  );

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.existingKey ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    // _validateKey resolves its messages via JsonFormLocalizations (an
    // inherited dependency), so the initial validation cannot run in
    // initState. Runs before the first build, hence no setState.
    _keyError = _validateKey(_keyController.text);

    if (_keyError == null) {
      unawaited(_init());
    }
  }

  Future<void> _init() {
    return _snapshotGuard.run(
      () => EntryEditorSnapshot.build(
        key: _keyController.text.trim(),
        initialState: widget.existingState,
        schema: widget.schema,
        additionalPropertiesAllowed: _additionalPropertiesAllowed,
        displayContext: widget.displayContext,
        handlerRegistry: widget.handlerRegistry,
        fieldNamePatterns: widget.fieldNamePatterns,
      ),
      (newSnapshot) => setState(() => _snapshot = newSnapshot),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  String? _validateKey(String text) {
    final l10n = jsonFormLocalizationsOf(context);
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return l10n.keyEmptyError;
    }
    if (widget.forbiddenKeys.contains(trimmed)) {
      return l10n.keyExistsError;
    }

    if (!_additionalPropertiesAllowed) {
      final isKnown = widget.schema?.properties?.containsKey(trimmed) ?? false;
      final matchesPattern = widget.fieldNamePatterns.keys.any((regExp) => regExp.hasMatch(trimmed));
      if (!isKnown && !matchesPattern) {
        return l10n.additionalPropertiesForbiddenError(trimmed);
      }
    }
    return null;
  }

  Future<void> _onKeyChanged(String text) async {
    final trimmed = text.trim();
    if (trimmed == _snapshot?.key) return;

    final keyError = _validateKey(trimmed);
    if (keyError != null) {
      // A snapshot built for a previously valid key must not appear after
      // the key became invalid.
      _snapshotGuard.cancelPending();
      if (_keyError != keyError || _snapshot != null) {
        setState(() {
          _keyError = keyError;
          _snapshot = null; // Reset the stale state for the invalid key
        });
      }
      return;
    }

    return _snapshotGuard.run(
      () => EntryEditorSnapshot.build(
        key: trimmed,
        previousSnapshot: _snapshot,
        additionalPropertiesAllowed: _additionalPropertiesAllowed,
        displayContext: widget.displayContext,
        handlerRegistry: widget.handlerRegistry,
        schema: widget.schema,
        fieldNamePatterns: widget.fieldNamePatterns,
      ),
      (newSnapshot) => setState(() {
        _keyError = null;
        _snapshot = newSnapshot;
      }),
    );
  }

  Future<void> _onFieldChanged(JsonFieldState? fieldState) {
    return _snapshotGuard.run(
      () async => _snapshot?.applyFieldState(fieldState),
      (newSnapshot) => setState(() => _snapshot = newSnapshot),
    );
  }

  Future<void> _onHandlerChanged(FieldHandlerBinding selectedHandler) async {
    final snapshot = _snapshot;
    if (snapshot == null) return;

    return _snapshotGuard.run(
      () => snapshot.applyHandler(handler: selectedHandler, displayContext: widget.displayContext, handlerRegistry: widget.handlerRegistry),
      (newSnapshot) => setState(() => _snapshot = newSnapshot),
    );
  }

  bool get _canSubmit {
    // When key is read-only, skip key validation — it's pre-validated by schema
    final keyValid = widget.keyReadOnly ? _keyController.text.trim().isNotEmpty : _keyError == null && _keyController.text.trim().isNotEmpty;
    final snapshot = _snapshot;
    if (snapshot == null || !keyValid) return false;

    // An entry must carry a representable value: an absent value is never
    // submittable (for scalars without a canonical empty value — bool, int,
    // double — OK stays disabled until something is entered; array, object
    // and string are seeded with []/{}/'' on selection and pass). An
    // explicit null is committable only by editors that can produce null
    // (the Null handler, the raw JSON one) — for others it would put a
    // value of the wrong type into the document.
    final fieldState = snapshot.fieldState;
    if (fieldState == null || !fieldState.hasValue) return false;
    if (fieldState.valueOrNull == null && !snapshot.selectedHandler.fieldHandler.canEditValue(null)) {
      return false;
    }

    // Every snapshot path validates the value via applyErrors, which marks
    // the state validated (errors == [] when clean, see
    // JsonFieldState.errors), so isSubmittable is false only for a failed
    // validation or a state that skipped the snapshot pipeline entirely.
    // Which errors block is the registry's validation mode's decision (a
    // validator-rejected schema does not block under lenient/none).
    return fieldState.isSubmittable(widget.handlerRegistry.validationMode);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final l10n = jsonFormLocalizationsOf(context);

    final snapshot = _snapshot;
    final fieldState = snapshot?.fieldState;
    final fieldPadding = FormTheme.of(context).fieldPadding;

    return FormDialog(
      title: Text(widget.existingKey != null ? l10n.editEntryDialogTitle : l10n.addEntryDialogTitle),
      onClose: () => Navigator.pop(context),
      // The width policy (min(480, available), content-independent) lives in
      // FormDialog.contentMaxWidth.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: fieldPadding,
            child: TextField(
              autofocus: true,
              controller: _keyController,
              readOnly: widget.keyReadOnly,
              decoration: InputDecoration(
                labelText: l10n.keyFieldLabel,
                errorText: widget.keyReadOnly ? null : _keyError,
                // Visual hint that the key is locked
                suffixIcon: widget.keyReadOnly ? const Icon(Icons.lock_outline, size: 16) : null,
              ),
              onChanged: widget.keyReadOnly ? null : _onKeyChanged,
            ),
          ),
          if (snapshot != null) ...[
            if (snapshot.availableHandlers.length > 1)
              Padding(
                padding: fieldPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.valueTypeLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    DropdownButton<FieldHandlerBinding>(
                      isExpanded: true,
                      items: snapshot.availableHandlers
                          .map(
                            (handlerBinding) => DropdownMenuItem(
                              value: handlerBinding,
                              child: Text(handlerBinding.fieldHandler.typeDisplayName(context)),
                            ),
                          )
                          .toList(growable: false),
                      value: snapshot.selectedHandler,
                      onChanged: (selected) => selected != null ? _onHandlerChanged(selected) : null,
                    ),
                  ],
                ),
              ),
            if (fieldState != null)
              snapshot.selectedHandler.fieldHandler.buildField(
                displayContext: widget.displayContext.child(snapshot.key),
                context: context,
                onChanged: _onFieldChanged,
                fieldState: fieldState,
              ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _canSubmit && snapshot != null
              ? () => Navigator.pop(
                  context,
                  (_keyController.text.trim(), snapshot.fieldState),
                )
              : null,
          child: Text(localizations.okButtonLabel),
        ),
      ],
    );
  }
}
