import 'package:material_ui/material_ui.dart';

/// The label of a form field: the title text (truncated with an ellipsis
/// when it does not fit) plus the required asterisk, which is never
/// truncated away. Used as `InputDecoration.label` by every field widget so
/// required marking looks identical across the form.
class FieldLabel extends StatelessWidget {
  /// Creates a field label.
  const FieldLabel({
    this.label,
    this.isRequired = false,
    super.key,
  });

  /// The title text; with null/empty only the asterisk (if any) is shown.
  final String? label;

  /// Appends the error-colored asterisk.
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final labelLoc = label;
    final hasLabel = labelLoc != null && labelLoc.isNotEmpty;

    if (!hasLabel) {
      if (!isRequired) return const SizedBox.shrink();

      return Text(
        '*',
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The title text shrinks and gets truncated with "..." if it doesn't fit
        Flexible(
          child: Text(
            labelLoc,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // The asterisk is guaranteed to be shown on the right
        if (isRequired) ...[
          const SizedBox(width: 4),
          Text(
            '*',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }
}
