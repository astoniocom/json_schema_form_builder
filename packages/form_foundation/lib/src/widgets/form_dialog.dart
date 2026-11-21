import 'package:material_ui/material_ui.dart';

import 'form_theme.dart';

/// An [AlertDialog] wrapper shared by the form dialogs.
///
/// The title and the actions row are horizontally aligned with the form
/// fields: their padding is derived from [FormThemeData.fieldPadding].
/// The content gets zero padding because the fields inside already carry
/// fieldPadding themselves.
class FormDialog extends StatelessWidget {
  /// Creates a form dialog.
  const FormDialog({
    required this.title,
    required this.content,
    this.actions = const [],
    this.onClose,
    this.contentMaxWidth = 480,
    super.key,
  });

  /// The dialog title, aligned with the form fields below.
  final Widget title;

  /// The dialog body; typically a column of form fields.
  final Widget content;

  /// The buttons row (Cancel/OK), aligned with the form fields.
  final List<Widget> actions;

  /// When non-null, a [CloseButton] is appended to the title row.
  final VoidCallback? onClose;

  /// The dialog content always takes `min(contentMaxWidth, available width)`
  /// — a width independent of the content. This is load-bearing, not
  /// cosmetics: [AlertDialog] shrink-wraps its content by intrinsic width,
  /// while form editors choose their representation by the width they get
  /// (WidthThresholdBuilder: inline editor vs collapsed button). Those two
  /// rules form a feedback loop — the chosen variant changes the intrinsic
  /// width, which changes the dialog width, which flips the choice back —
  /// and the dialog flickers between variants every frame. A content-
  /// independent width breaks the loop.
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context) {
    final fieldPadding = FormTheme.of(context).fieldPadding.resolve(Directionality.maybeOf(context));
    final onCloseLoc = onClose;

    return AlertDialog(
      titlePadding: EdgeInsets.only(
        left: fieldPadding.left,
        right: fieldPadding.right,
        top: 24,
        bottom: 24 - fieldPadding.top,
      ),
      title: onCloseLoc == null
          ? title
          : Row(
              children: [
                Expanded(child: title),
                CloseButton(onPressed: onCloseLoc),
              ],
            ),
      contentPadding: EdgeInsets.zero,
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        // maxFinite expands to the smaller of contentMaxWidth and the space
        // the dialog inset leaves, pinning the width (see contentMaxWidth).
        child: SizedBox(width: double.maxFinite, child: content),
      ),
      actionsPadding: EdgeInsets.only(
        left: fieldPadding.left,
        right: fieldPadding.right,
        top: 24,
        bottom: 24 - fieldPadding.bottom,
      ),
      actions: actions,
    );
  }
}
