import 'package:material_ui/material_ui.dart';

import '../models/field_handler.dart';
import '../models/field_handler_registry.dart';
import '../models/node_state.dart';
import 'editor_group.dart';
import 'form_theme.dart';
import 'min_height_setter.dart';
import 'removable_row.dart';

/// The editor of a keyed container (a JSON object): one removable row per
/// entry of [fieldStates], each rendered by the handler its state maps to,
/// framed by an [EditorGroup].
///
/// Type parameters: [K] — the entry key; [V] — the state type emitted by the
/// child handlers' onChanged; [FieldState] — the base state type of the
/// registry; [FE] — the entry wrapper around a child state; [DisplayContext]
/// and [H] — as in [FieldHandler].
class NodeEditor<K, V, FieldState, FE extends MapFieldEntry<FieldState>, DisplayContext, H extends FieldHandler<FieldState, V, DisplayContext>>
    extends StatelessWidget {
  /// Creates a node editor for [fieldStates].
  const NodeEditor({
    required this.handlerRegistry,
    required this.displayContextForField,
    required this.fieldStates,
    this.onChanged,
    this.testCanRemoveEntry,
    this.onRemove,
    this.addButton,
    this.title,
    this.errors,
    this.helpText,
    this.view = EditorGroupView.framed,
    this.child,
    super.key,
  });

  /// A child edit: the entry key, the handler that produced it and the new
  /// state. Null renders every child read-only.
  final void Function(K, H, V)? onChanged;

  /// Removes an entry; null hides all delete buttons.
  final void Function(MapEntry<K, FE>)? onRemove;

  /// The "add entry" button; composed into the rows (or, for an empty framed
  /// editor, into the frame's suffix slot).
  final Widget? addButton;

  /// Maps each child state to the handler rendering it.
  final FieldHandlerRegistry<FieldState, DisplayContext, H> handlerRegistry;

  /// Builds the display context a child is rendered with.
  final DisplayContext Function(K key, FieldState fieldState) displayContextForField;

  /// The group title.
  final String? title;

  /// Validation messages of the container itself (child errors are rendered
  /// by the child fields).
  final Iterable<String>? errors;

  /// Helper text under the title.
  final String? helpText;

  /// The entries to render, in map order.
  final Map<K, FE> fieldStates;

  /// Per-entry veto on removal (e.g. schema-required properties); the delete
  /// button is also hidden when [onRemove] is null.
  final bool Function(MapEntry<K, FE>)? testCanRemoveEntry;

  /// The presentation variant, see [EditorGroupView].
  final EditorGroupView view;

  /// Extra content appended after the rows (e.g. a variant switcher).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final field in fieldStates.entries) {
      final handler = handlerRegistry.handlerForField(field.value.state);
      final canBeRemoved = (testCanRemoveEntry?.call(field) ?? true) && onRemove != null;
      children.add(
        RemovableRow(
          field: handler.buildField(
            context: context,
            fieldState: field.value.state,
            onChanged: onChanged != null ? (newValue) => onChanged?.call(field.key, handler, newValue) : null,
            displayContext: displayContextForField(field.key, field.value.state),
          ),
          onRemove: canBeRemoved ? () => onRemove?.call(field) : null,
        ),
      );
    }

    // Only the framed view may collapse an empty editor to a single line (the
    // add button then becomes the frame's suffix icon). Expanded views always
    // need the button row, or an empty node could never be filled.
    final collapsible = view == EditorGroupView.framed && children.isEmpty && child == null;
    if (addButton != null && !collapsible) {
      children.add(
        Padding(
          padding: FormTheme.fieldPaddingOf(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              addButton!,
              const MinHeightSetter(),
            ],
          ),
        ),
      );
    }

    if (child != null) {
      children.add(child!);
    }

    return EditorGroup(
      title: title,
      helpText: helpText,
      errors: errors ?? const [],
      content: children.isNotEmpty ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: children) : null,
      addButton: addButton,
      view: view,
    );
  }
}
