import 'package:material_ui/material_ui.dart';

/// Generic overlay logic for a dropdown list of example values,
/// anchored to a field via CompositedTransformTarget/Follower.
///
/// E — the example value type (String, num, ...)
/// T — the StatefulWidget type using the mixin
mixin ExamplesDropdownMixin<E, T extends StatefulWidget> on State<T> {
  /// Assigned to the anchor field so the overlay can measure its size.
  @protected
  final GlobalKey fieldKey = GlobalKey();

  /// Links the anchor (CompositedTransformTarget wrapping the field) with
  /// the overlay follower positioning the dropdown.
  @protected
  final LayerLink layerLink = LayerLink();

  OverlayEntry? _overlayEntry;

  /// Whether the dropdown overlay is currently shown; drives the toggle
  /// icon's direction.
  @protected
  bool isDropdownOpen = false;

  /// Overridden in a subclass to render a list item
  String exampleLabel(E example) => example.toString();

  /// Opens the dropdown listing [examples] (closes it when already open);
  /// a picked value is delivered to [onSelect].
  @protected
  void toggleExamplesDropdown(List<E>? examples, ValueChanged<E> onSelect) {
    if (examples == null || examples.isEmpty) return;
    if (isDropdownOpen) {
      removeExamplesOverlay();
    } else {
      _showExamplesOverlay(examples, onSelect);
    }
  }

  void _showExamplesOverlay(List<E> examples, ValueChanged<E> onSelect) {
    final renderBox = fieldKey.currentContext?.findRenderObject();
    if (renderBox is! RenderBox) return;

    final width = renderBox.size.width;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // A transparent full-screen barrier: a tap outside the list
            // closes the dropdown and absorbs the press, like standard menus.
            // It also makes a repeated tap on the toggle icon close the
            // dropdown (the icon is under the barrier too).
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: removeExamplesOverlay,
              ),
            ),
            Positioned(
              width: width,
              child: CompositedTransformFollower(
                link: layerLink,
                showWhenUnlinked: false,
                offset: Offset(0, renderBox.size.height + 4),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(4),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: examples.length,
                      itemBuilder: (context, index) {
                        final example = examples[index];
                        return InkWell(
                          onTap: () {
                            onSelect(example);
                            removeExamplesOverlay();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Text(exampleLabel(example)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => isDropdownOpen = true);
  }

  /// Closes the dropdown if it is open.
  @protected
  void removeExamplesOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (isDropdownOpen && mounted) {
      setState(() => isDropdownOpen = false);
    }
  }

  /// Called from the subclass's dispose: tears the overlay down without
  /// touching the (already defunct) state.
  @mustCallSuper
  @protected
  void disposeExamplesOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
