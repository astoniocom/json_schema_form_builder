import 'package:material_ui/material_ui.dart';

import 'errors_panel.dart';
import 'form_theme.dart';

/// How [EditorGroup] presents itself.
enum EditorGroupView {
  /// An [InputDecorator] frame with the title as its label; collapses to a
  /// single line when there is no content (nested editors).
  framed,

  /// Expanded frameless layout with a title row (form/dialog root).
  expanded,

  /// Expanded frameless layout without the title row (e.g. a variant
  /// alternative whose header is already shown by the parent).
  expandedWithoutTitle,
}

/// The shared frame of collection editors (NodeEditor, ListEditor).
///
/// The editors compose the add button row into [content] themselves; here
/// [addButton] is only shown as the suffix icon of the collapsed framed
/// view, so an empty framed group stays a single line.
class EditorGroup extends StatelessWidget {
  /// Creates a group frame around [content].
  const EditorGroup({
    this.errors = const [],
    this.content,
    this.addButton,
    this.title,
    this.helpText,
    this.view = EditorGroupView.framed,
    super.key,
  });

  /// Validation messages of the container itself, shown via ErrorsPanel
  /// (child errors are rendered by the child fields).
  final Iterable<String> errors;

  /// The editor's rows; null when there are none.
  final Widget? content;

  /// The collection editor's add button; shown as the suffix icon of the
  /// collapsed framed view (the editors compose it into [content] otherwise).
  final Widget? addButton;

  /// The group title: the frame label (framed view) or the title row.
  final String? title;

  /// Helper text under the title.
  final String? helpText;

  /// The presentation variant, see [EditorGroupView].
  final EditorGroupView view;

  @override
  Widget build(BuildContext context) {
    if (view != EditorGroupView.framed) return _expandedContent(context, insideFrame: false);

    // An explicit `border` fills only the base slot, so state borders
    // (enabled/focused/error) configured by the app's inputDecorationTheme
    // still win.
    final border = FormTheme.groupBorderOf(context);
    if (content == null) {
      return Padding(
        padding: FormTheme.fieldPaddingOf(context),
        child: InputDecorator(
          isEmpty: true,
          decoration: InputDecoration(
            border: border,
            labelText: title,
            errorText: errors.isNotEmpty ? errors.join('\n') : null,
            helperText: helpText,
            suffixIcon: addButton,
          ),
          // The invisible text keeps the collapsed decorator at the height of
          // a regular single-line field.
          child: const Opacity(opacity: 0, child: Text('1')),
        ),
      );
    }
    // Inside InputDecorator both the floating label and the content are
    // positioned from contentPadding.start, so a single decorator cannot
    // indent the label while keeping the content flush. Instead the frame
    // and its label are drawn by a childless decorator stretched behind the
    // content, and the content lays itself out with no horizontal inset.
    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: Stack(
        children: [
          Positioned.fill(
            child: InputDecorator(
              expands: true,
              decoration: InputDecoration(
                border: border,
                // Indents only the label, following the horizontal
                // contentPadding of the app theme, so collapsed and expanded
                // labels align.
                contentPadding: FormTheme.groupLabelPaddingOf(context),
                labelText: title,
                filled: false,
              ),
              child: const SizedBox.shrink(),
            ),
          ),
          // Breathing room between the frame line and the editor rows.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: _expandedContent(context, insideFrame: true),
          ),
        ],
      ),
    );
  }

  /// The expanded layout: title/help rows, errors and the editor rows.
  /// Inside the frame the title row is omitted — the frame's label already
  /// shows it.
  Widget _expandedContent(BuildContext context, {required bool insideFrame}) {
    final theme = Theme.of(context);
    final titleLoc = title;
    final helpTextLoc = helpText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titleLoc != null && !insideFrame && view != EditorGroupView.expandedWithoutTitle)
          Padding(
            padding: FormTheme.fieldPaddingOf(context),
            child: Text(titleLoc, style: theme.textTheme.titleMedium),
          ),
        if (helpTextLoc != null)
          Padding(
            padding: FormTheme.fieldPaddingOf(context),
            child: Text(helpTextLoc, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          ),
        if (errors.isNotEmpty) ErrorsPanel(errors: errors),
        ?content,
      ],
    );
  }
}
