import 'package:material_ui/material_ui.dart';

import '../../form_foundation.dart';
import 'min_height_setter.dart';

/// A row of a collection editor: the field itself plus the trailing action
/// column (delete button, optional drag handle). An invisible
/// MinHeightSetter keeps the action column at least one field-row tall, so
/// the buttons stay vertically centered against a one-line field.
class RemovableRow extends StatelessWidget {
  /// Creates a removable row around [field].
  const RemovableRow({
    required this.field,
    required this.onRemove,
    this.dragHandle,
    super.key,
  });

  /// The row content (the child field's editor).
  final Widget field;

  /// The drag-and-drop handle, when the hosting list supports reordering.
  final Widget? dragHandle;

  /// Removes this row; null hides the delete button.
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final children = [
      if (onRemove != null) ...[
        Row(
          children: [
            const MinHeightSetter(),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.delete),
            ),
          ],
        ),
      ],
      if (dragHandle != null) ...[
        dragHandle!,
      ],
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: field),
        Padding(
          padding: children.isNotEmpty ? FormTheme.of(context).fieldPadding.resolve(null).copyWith(left: 0) : EdgeInsets.zero,
          child: Row(
            children: children,
          ),
        ),
        // if (children.isNotEmpty) SizedBox(width: rightPadding),
      ],
    );
  }
}
