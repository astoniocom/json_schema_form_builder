import 'package:material_ui/material_ui.dart';

/// Shared logic for a text field that edits a typed value [V]:
///
/// - owning the [FocusNode] (an internal one is created when no external
///   one is provided, replacement of the external one is handled, the
///   internal one gets disposed);
/// - canonicalizing the text on focus loss (intermediate input like "-"
///   or "007" is converted to the canonical form of the value);
/// - syncing the controller with [fieldValue] in didUpdateWidget: without
///   focus the controller is always set to the value; with focus a gate
///   applies, protecting fresh user input from being overwritten by a stale
///   value coming from async processing higher up the tree.
///
/// A subclass must:
/// - override [fieldValue], [externalFocusNode], [formatValue],
///   [parseValue] (and [valuesEquivalent] if needed);
/// - call [initTextValueSync] from initState;
/// - call [syncTextValueField] from didUpdateWidget, passing the old
///   value and focusNode;
/// - call [disposeTextValueSync] from dispose (the controller is disposed there).
///
/// V — the field value type (int, double, String, ...)
/// T — the StatefulWidget type using the mixin
mixin TextValueSyncMixin<V, T extends StatefulWidget> on State<T> {
  /// Current value from the widget (usually `widget.value`).
  @protected
  V? get fieldValue;

  /// External FocusNode from the widget (usually `widget.focusNode`).
  @protected
  FocusNode? get externalFocusNode;

  /// Canonical text representation of the value.
  @protected
  String formatValue(V? value);

  /// Parses text into a value; null means the text is not a value
  /// (empty or an intermediate input state).
  @protected
  V? parseValue(String text);

  /// Compares parsed user input with the external value.
  /// Override when exact equality is not enough (e.g. an epsilon
  /// for double).
  @protected
  bool valuesEquivalent(V? parsed, V? target) => parsed == target;

  /// The text controller of the field, owned and disposed by the mixin.
  @protected
  late final TextEditingController controller = TextEditingController(
    text: formatValue(fieldValue),
  );

  /// The effective focus node: [externalFocusNode] when provided, otherwise
  /// an internal one owned by the mixin.
  @protected
  late FocusNode focusNode;
  bool _createdInternalFocusNode = false;

  /// Called from the subclass's initState.
  @protected
  void initTextValueSync() {
    _attachFocusNode();
  }

  /// Called from the subclass's didUpdateWidget.
  @protected
  void syncTextValueField({
    required V? oldValue,
    required FocusNode? oldFocusNode,
  }) {
    // 1. Handle replacement of the external FocusNode
    if (externalFocusNode != oldFocusNode) {
      _detachFocusNode();
      _attachFocusNode();
    }

    // 2. State synchronization
    if (!focusNode.hasFocus) {
      setControllerText(formatValue(fieldValue));
    } else if (fieldValue != oldValue) {
      // The gate is needed regardless of the Key: a Key guarantees this is
      // the same logical element, but not that fieldValue has already caught
      // up with the value the user just entered (async processing somewhere
      // higher up the tree). Without this gate, an unrelated rebuild could
      // overwrite fresh input with a stale value.
      final currentParsed = parseValue(controller.text);
      if (!valuesEquivalent(currentParsed, fieldValue)) {
        setControllerText(formatValue(fieldValue));
      }
    }
  }

  /// Called from the subclass's dispose.
  @protected
  void disposeTextValueSync() {
    _detachFocusNode();
    controller.dispose();
  }

  /// Writes text into the controller with the cursor at the end,
  /// leaving the controller untouched if the text already matches.
  @protected
  void setControllerText(String text) {
    if (controller.text == text) return;
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _attachFocusNode() {
    final external = externalFocusNode;
    if (external != null) {
      focusNode = external;
      _createdInternalFocusNode = false;
    } else {
      focusNode = FocusNode();
      _createdInternalFocusNode = true;
    }
    focusNode.addListener(_onFocusChange);
  }

  void _detachFocusNode() {
    focusNode.removeListener(_onFocusChange);
    if (_createdInternalFocusNode) {
      focusNode.dispose();
    }
  }

  void _onFocusChange() {
    if (!focusNode.hasFocus) {
      final currentParsed = parseValue(controller.text);
      final canonicalValue = currentParsed ?? fieldValue;
      setControllerText(formatValue(canonicalValue));
    }
  }
}
