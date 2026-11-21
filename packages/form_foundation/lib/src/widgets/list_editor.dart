import 'package:material_ui/material_ui.dart';

import '../models/field_handler.dart';
import '../models/field_handler_registry.dart';
import 'editor_group.dart';
import 'form_theme.dart';
import 'min_height_setter.dart';
import 'removable_row.dart';

/// The editor of an indexed container (a JSON array): one removable — and,
/// with [onReorder], drag-reorderable — row per element of [children], each
/// rendered by the handler its state maps to, framed by an [EditorGroup].
///
/// Type parameters as in [FieldHandler]; list rows emit the same state type
/// they render, hence `FieldHandler<FieldState, FieldState, DisplayContext>`.
class ListEditor<FieldState, DisplayContext, Handler extends FieldHandler<FieldState, FieldState, DisplayContext>> extends StatefulWidget {
  /// Creates a list editor for [children].
  const ListEditor({
    required this.handlerRegistry,
    required this.displayContextForField,
    this.onChanged,
    this.onRemoved,
    this.onReorder,
    this.addButton,
    this.title,
    this.errors,
    this.helpText,
    this.children,
    this.view = EditorGroupView.framed,
    this.child,
    super.key,
  });

  /// An element edit: the index and the new state. Null renders every
  /// element read-only.
  final void Function(int index, FieldState newValue)? onChanged;

  /// Removes an element; null hides all delete buttons.
  final void Function(int index)? onRemoved;

  /// The "add item" button; composed into the rows (or, for an empty framed
  /// editor, into the frame's suffix slot).
  final Widget? addButton;

  /// Maps each element state to the handler rendering it.
  final FieldHandlerRegistry<FieldState, DisplayContext, Handler> handlerRegistry;

  /// Builds the display context an element is rendered with.
  final DisplayContext Function(int index, FieldState fieldState) displayContextForField;

  /// The group title.
  final String? title;

  /// Validation messages of the container itself (element errors are
  /// rendered by the element fields).
  final Iterable<String>? errors;

  /// Helper text under the title.
  final String? helpText;

  /// The element states to render, in list order.
  final List<FieldState>? children;

  /// Applies a drag-and-drop move; null disables reordering (no handles).
  final void Function(int oldIndex, int newIndex)? onReorder;

  /// The presentation variant, see [EditorGroupView].
  final EditorGroupView view;

  /// Extra content appended after the rows (e.g. a variant switcher).
  final Widget? child;

  @override
  State<ListEditor<FieldState, DisplayContext, Handler>> createState() => _ListEditorState<FieldState, DisplayContext, Handler>();
}

class _ListEditorState<FieldState, DisplayContext, Handler extends FieldHandler<FieldState, FieldState, DisplayContext>>
    extends State<ListEditor<FieldState, DisplayContext, Handler>> {
  /// Identifies this list instance in drag-and-drop payloads, so rows dragged
  /// out of one list are not accepted by the drop targets of another list.
  /// Lives in the state to stay stable across rebuilds during a drag.
  final Object _dragScope = Object();

  Widget _buildFieldRow(BuildContext context, int index, FieldState field) {
    return widget.handlerRegistry
        .handlerForField(field)
        .buildField(
          context: context,
          fieldState: field,
          displayContext: widget.displayContextForField(index, field),
          onChanged: widget.onChanged != null ? (newValue) => widget.onChanged?.call(index, newValue) : null,
        );
  }

  VoidCallback? _onRemoveForRow(int index) {
    final onRemovedLoc = widget.onRemoved;
    return onRemovedLoc != null ? () => onRemovedLoc(index) : null;
  }

  Widget? _listModeWidget(BuildContext context) {
    final childrenLoc = widget.children ?? const [];
    // Only the framed view may collapse an empty editor to a single line (the
    // add button then becomes the frame's suffix icon). Expanded views always
    // need the button row, or an empty list could never be filled. The
    // variant switcher ([child]) is content too and must not collapse away.
    if (widget.view == EditorGroupView.framed && childrenLoc.isEmpty && widget.child == null) return null;

    final children = <Widget>[];
    for (final (index, field) in childrenLoc.indexed) {
      final fieldRow = _buildFieldRow(context, index, field);
      children.add(
        widget.onReorder != null && childrenLoc.length > 1
            ? _ReorderableRow(
                key: ValueKey(index),
                // key: ObjectKey(field), // with key the internal TextField loses focus after each letter typed.
                index: index,
                dragScope: _dragScope,
                onReorder: widget.onReorder!,
                onRemove: _onRemoveForRow(index),
                child: fieldRow,
              )
            : RemovableRow(
                field: fieldRow,
                onRemove: _onRemoveForRow(index),
              ),
      );
    }

    final collapsible = widget.view == EditorGroupView.framed && children.isEmpty && widget.child == null;
    if (widget.addButton != null && !collapsible) {
      children.add(
        Padding(
          padding: FormTheme.fieldPaddingOf(context),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              widget.addButton!,
              const MinHeightSetter(),
            ],
          ),
        ),
      );
    }

    if (widget.child != null) {
      children.add(widget.child!);
    }

    return children.isEmpty ? null : Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  @override
  Widget build(BuildContext context) {
    return EditorGroup(
      title: widget.title,
      helpText: widget.helpText,
      errors: widget.errors ?? const [],
      content: _listModeWidget(context),
      addButton: widget.addButton,
      view: widget.view,
    );
  }
}

/// Drag-and-drop payload of a list row: the row index plus the identity of
/// the owning list, so a row cannot be dropped onto a different list.
class _ListDragData {
  const _ListDragData({required this.scope, required this.index});

  final Object scope;
  final int index;
}

/// A list row supporting drag-and-drop reordering.
/// Measures its own width after layout (via RenderBox rather than
/// LayoutBuilder — LayoutBuilder needs an intrinsics-friendly parent, which
/// is not guaranteed inside the EditorGroup frame or a Row up the tree) and
/// uses that width for the drag feedback widget so it does not stretch to
/// the full screen inside the fullscreen Overlay.
class _ReorderableRow extends StatefulWidget {
  const _ReorderableRow({
    required this.index,
    required this.dragScope,
    required this.onReorder,
    required this.onRemove,
    required this.child,
    required super.key,
  });

  final int index;

  /// Identity of the list this row belongs to; see [_ListDragData].
  final Object dragScope;

  final void Function(int oldIndex, int newIndex) onReorder;

  /// Removes this row; null hides the delete button.
  final VoidCallback? onRemove;

  final Widget child;

  @override
  State<_ReorderableRow> createState() => _ReorderableRowState();
}

class _ReorderableRowState extends State<_ReorderableRow> {
  final _rowKey = GlobalKey();
  double? _measuredWidth;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMeasuredWidth());
  }

  @override
  void didUpdateWidget(covariant _ReorderableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateMeasuredWidth());
  }

  void _updateMeasuredWidth() {
    if (!mounted) return;
    final renderObject = _rowKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      _measuredWidth = renderObject.size.width;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DragTarget<_ListDragData>(
      onWillAcceptWithDetails: (details) => identical(details.data.scope, widget.dragScope) && details.data.index != widget.index,
      onAcceptWithDetails: (details) {
        final oldIndex = details.data.index;
        final newIndex = widget.index;

        if (oldIndex == newIndex) return;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          widget.onReorder(oldIndex, newIndex);
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;

        final handle = Stack(
          children: [
            const Opacity(opacity: 0, child: IconButton(onPressed: null, icon: Icon(Icons.abc))),
            Positioned.fill(
              child: Center(child: Icon(Icons.drag_handle, color: Theme.of(context).disabledColor)),
            ),
          ],
        );

        return Opacity(
          key: _rowKey,
          opacity: _isDragging ? 0.2 : 1,
          child: Stack(
            children: [
              RemovableRow(
                onRemove: widget.onRemove,
                field: widget.child,
                dragHandle: Draggable<_ListDragData>(
                  data: _ListDragData(scope: widget.dragScope, index: widget.index),
                  axis: Axis.vertical,
                  dragAnchorStrategy: (draggable, context, position) {
                    final rowBox = _rowKey.currentContext?.findRenderObject();
                    if (rowBox is RenderBox && rowBox.hasSize) {
                      return rowBox.globalToLocal(position);
                    }
                    return childDragAnchorStrategy(draggable, context, position);
                  },
                  onDragStarted: () {
                    if (!mounted) return;
                    _updateMeasuredWidth();
                    setState(() => _isDragging = true);
                  },
                  onDragEnd: (_) {
                    if (!mounted) return;
                    setState(() => _isDragging = false);
                  },
                  feedback: Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(4),
                    // Builder defers reading _measuredWidth until the overlay
                    // builds the drag avatar, which happens after
                    // onDragStarted has measured the row. Without it the
                    // width captured at the last rebuild is used, which is
                    // still null on the first drag (the post-frame
                    // measurement does not trigger a rebuild), so the row
                    // stretched to the full screen width.
                    child: Builder(
                      builder: (context) => SizedBox(
                        // without MediaQuery.of(context).size.width there is sometimes an error when reordering starts
                        width: _measuredWidth ?? MediaQuery.of(context).size.width,
                        child: RemovableRow(
                          field: widget.child,
                          // Not tappable while dragging; passed only so the
                          // feedback keeps the same layout as the source row.
                          onRemove: widget.onRemove,
                          dragHandle: handle,
                        ),
                      ),
                    ),
                  ),
                  childWhenDragging: IgnorePointer(
                    child: handle,
                  ),
                  child: handle,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      border: isDropTarget ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
