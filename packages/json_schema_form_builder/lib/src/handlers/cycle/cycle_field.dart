import 'dart:async';

import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/cycle_field_state.dart';
import '../../models/field_build_request.dart';
import '../../models/field_context.dart';
import '../../models/json_field_state.dart';
import '../../models/json_handler_registry.dart';
import '../../utils/latest_request_guard.dart';

/// The field standing at a recursion cut-off point (see [CycleFieldState]).
///
/// This widget is a PERMANENT wrapper for its document position: the guard
/// produces a [CycleFieldState] at a repeated `$ref` regardless of the value,
/// so host rebuilds (which re-derive the whole state tree from the value on
/// every change) never swap the widget type here. That keeps the element
/// subtree — and the focus of a field being typed into — alive across the
/// rebuild triggered by each keystroke.
///
/// Behavior:
///  - valueless, not expanded: a collapsed row with an "Expand cycle" button;
///    a press builds one more level through the registry pipeline (with this
///    field's `$ref` removed from the descent's expanded set — the repeat one
///    level below collapses into the next CycleField);
///  - with a value (or after a press): the real subtree is built and rendered
///    in place, rebuilt from the fresh state on every host rebuild ("latest
///    request wins", the previous subtree stays rendered meanwhile).
///
/// Expansion itself writes no value: it is a UI reveal, not a document edit.
class CycleField extends StatefulWidget {
  /// Creates a cycle field; null [onChanged] renders it read-only.
  const CycleField({
    required this.fieldState,
    required this.registry,
    required this.displayContext,
    required this.onChanged,
    super.key,
  });

  /// The collapsed state built by the registry's cycle guard.
  final CycleFieldState fieldState;

  /// The registry the expanded subtree is built and rendered through.
  final JsonHandlerRegistry registry;

  /// Where the field sits (dialog depth, header visibility).
  final FieldDisplayContext displayContext;

  /// Receives this field's updated CycleFieldState on edits inside the
  /// expanded subtree; null disables editing.
  final ValueChanged<JsonFieldState>? onChanged;

  @override
  State<CycleField> createState() => _CycleFieldState();
}

class _CycleFieldState extends State<CycleField> {
  late final LatestRequestGuard _expandGuard = LatestRequestGuard(isAlive: () => mounted);

  /// The subtree state rendered in place of the collapsed row. Built here,
  /// not by the host pipeline (the guard cuts the host's descent).
  JsonFieldState? _expanded;

  /// Whether the user expanded this (still valueless) field: kept across
  /// host rebuilds — collapsing back on every keystroke elsewhere would make
  /// the button useless.
  bool _userExpanded = false;

  bool _expanding = false;

  bool get _hasValue => widget.fieldState.value.valueOrNull != null;

  @override
  void initState() {
    super.initState();
    if (_hasValue) _rebuildExpanded();
  }

  @override
  void didUpdateWidget(covariant CycleField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_hasValue && !_userExpanded) {
      _expanded = null;
      return;
    }

    // The host re-derives states from the value on every change; refresh the
    // expanded subtree when this field's slice actually changed. The old
    // subtree stays rendered until the new one arrives, so inner elements
    // (and focus) survive. Error lists are fresh instances on every
    // validation run, so they are not comparable by content cheaply: any
    // errors on either side trigger a refresh (a harmless over-rebuild).
    //
    // A schema change refreshes the same way — the expansion is KEPT, only
    // its content is rebuilt. Clearing the expansion here would collapse
    // every expanded level to the button row for the async gap and cascade
    // the re-expansion one level per hop (each nested CycleField only mounts
    // once its parent's subtree arrived), so the whole tree would visibly
    // jerk on every keystroke in a schema editor. A stale subtree rendered
    // for the gap is the lesser evil; latest-wins replaces it. When the
    // schema stops producing a cycle here at all, the host builds a
    // different state type and this widget is unmounted anyway.
    final errorsPresent = (oldWidget.fieldState.errors?.isNotEmpty ?? false) || (widget.fieldState.errors?.isNotEmpty ?? false);
    final schemaChanged = oldWidget.fieldState.schema?.value != widget.fieldState.schema?.value;
    final sliceChanged = oldWidget.fieldState.value != widget.fieldState.value || errorsPresent;
    if (_expanded == null || sliceChanged || schemaChanged) _rebuildExpanded();
  }

  void _rebuildExpanded() {
    final state = widget.fieldState;
    final schema = state.schema;
    if (schema == null) return;

    _expanding = true;
    unawaited(
      _expandGuard.run(
        () => widget.registry.withValidationContext(
          itemSchema: schema,
          rootSchema: state.rootSchema,
          body: (validationContext) => widget.registry.buildState(
            FieldBuildRequest(
              value: state.value,
              schemaSource: SchemaWithContext.maybe(schema, validationContext),
              title: state.title,
              required: state.fieldAnnotations?.required,
              readOnly: state.fieldAnnotations?.readOnly ?? false,
              errors: state.errors,
              resolveContext: FieldResolveContext(
                path: widget.displayContext.path,
                rootSchema: state.rootSchema,
                // Allow exactly one more expansion of this ref: the pipeline
                // records it again while descending, so the repeat one level
                // below collapses into the next CycleField.
                expandedRefs: state.expandedRefs.difference({state.ref}),
              ),
            ),
          ),
        ),
        (expanded) => setState(() {
          _expanding = false;
          if (expanded != null) _expanded = expanded;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expanded = _expanded;
    if (expanded != null) {
      return widget.registry
          .handlerForField(expanded)
          .buildField(
            context: context,
            fieldState: expanded,
            displayContext: widget.displayContext,
            onChanged: widget.onChanged == null
                ? null
                : (newState) {
                    // Render the edit immediately. Applying the pushed subtree
                    // locally is safe: any nested CycleField pushes a
                    // CycleFieldState too (below), so no position inside changes
                    // its widget type.
                    setState(() => _expanded = newState);
                    // Push OUR OWN state (a CycleFieldState carrying the new
                    // value), not the raw expanded state. Hosts that render
                    // pushed states directly (FieldEditorScreen, the entry edit
                    // dialog — unlike JsonSchemaForm, which only extracts the
                    // value) would otherwise show the real editor at this
                    // position, and the next pipeline rebuild would collapse it
                    // back to a CycleField — a widget-type flip that recreates
                    // the element (and kills focus) on every keystroke.
                    // The expanded subtree's errors (possibly "not validated",
                    // null) are carried over verbatim.
                    final expandedErrors = newState.errors;
                    final pushed = widget.fieldState.copyWith(value: newState.value);
                    widget.onChanged?.call(
                      expandedErrors == null ? pushed.markUnvalidated() : pushed.applyErrors(expandedErrors),
                    );
                  },
          );
    }

    final l10n = jsonFormLocalizationsOf(context);
    final state = widget.fieldState;

    return EditorGroup(
      title: state.title,
      helpText: state.fieldAnnotations?.description ?? l10n.cycleFieldHelperText,
      errors: state.errors?.map((e) => e.toErrorString()) ?? [],
      addButton: _expanding
          ? const IconButton(
              onPressed: null,
              icon: CircularProgressIndicator(strokeWidth: 2),
            )
          // Expansion only reveals UI (no document write), so readOnly
          // does not disable it; schema == null cannot happen for a
          // guard-built state but keeps the widget total.
          : IconButton(
              onPressed: state.schema != null
                  ? () {
                      setState(() => _userExpanded = true);
                      _rebuildExpanded();
                    }
                  : null,
              icon: const Icon(Icons.unfold_more),
              // An icon-only button: the action name lives in the tooltip
              // (also the accessibility label).
              tooltip: l10n.expandCycleButtonLabel,
            ),
    );
  }
}
