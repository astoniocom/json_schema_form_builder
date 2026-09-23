import 'package:flutter/material.dart';

/// One choice offered by an [AddButton]: what the menu row shows ([title])
/// and what the button reports when the row is picked ([data]).
class NewItemOption<D> {
  /// Creates an option labeled [title] carrying [data].
  NewItemOption({
    required this.title,
    required this.data,
  });

  /// The label of the menu row.
  final String title;

  /// The payload passed to [AddButton.onAdd] when this option is picked.
  final D data;
}

/// The "+" button of collection editors (object properties, array items).
///
/// With a single option in [typesToAdd] a press adds it directly; with
/// several, a press opens a menu and the picked option is added. Both
/// variants render the same icon button, so the two behaviors look
/// identical in place.
class AddButton<NewItemData> extends StatelessWidget {
  /// Creates an add button offering [typesToAdd]; null [onAdd] disables it.
  const AddButton({
    required this.typesToAdd,
    required this.onAdd,
    super.key,
  });

  /// The addable item kinds; their order is the menu order.
  final List<NewItemOption<NewItemData>> typesToAdd;

  /// Receives the picked option's data; null renders the button disabled.
  final void Function(NewItemData)? onAdd;

  @override
  Widget build(BuildContext context) {
    final newItemsLoc = typesToAdd;
    final onAddLoc = onAdd;

    if (newItemsLoc.length > 1) {
      // A real IconButton behind a MenuAnchor (not PopupMenuButton, whose
      // internal button positions the icon off the splash center): both
      // branches render the same button, so the two variants look identical.
      return MenuAnchor(
        menuChildren: newItemsLoc
            .map(
              (option) => MenuItemButton(
                onPressed: onAddLoc == null ? null : () => onAddLoc(option.data),
                child: Text(option.title),
              ),
            )
            .toList(growable: false),
        builder: (context, controller, child) => IconButton(
          onPressed: onAddLoc == null ? null : () => controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.add),
        ),
      );
    } else {
      return IconButton(
        onPressed: onAddLoc != null ? () => onAddLoc(newItemsLoc.first.data) : null,
        icon: const Icon(Icons.add),
      );
    }
  }
}
