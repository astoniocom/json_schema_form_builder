import 'package:flutter/material.dart';

import '../../form_foundation.dart';

/// A block listing validation errors of a node or a list.
///
/// Renders nothing when [errors] is empty. When visible, it spaces itself
/// with [FormThemeData.fieldPadding] like every other form block, so callers
/// don't have to manage the spacing to the content around it.
class ErrorsPanel extends StatelessWidget {
  /// Creates an errors panel; an empty [errors] renders nothing.
  const ErrorsPanel({
    this.errors = const [],
    super.key,
  });

  /// The messages to list, one selectable line each.
  final Iterable<String> errors;

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();

    final formTheme = FormTheme.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      // Announce newly appeared errors to assistive technologies.
      child: Semantics(
        liveRegion: true,
        child: Container(
          alignment: Alignment.topLeft,
          padding: formTheme.errorsPadding,
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final error in errors)
                // Selectable so validation messages can be copied.
                SelectableText(error, style: TextStyle(color: colorScheme.onErrorContainer)),
            ],
          ),
        ),
      ),
    );
  }
}
