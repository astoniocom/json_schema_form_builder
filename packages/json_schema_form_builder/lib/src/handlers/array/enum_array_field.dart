import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';

import '../../../json_schema_form_builder.dart';

/// The multi-select rendering of a unique-items array whose items schema is
/// select-like (ArrayFieldState.isEnum): one checkbox per admitted value,
/// checked when the array contains it. Mirrors react-jsonschema-form's
/// multi-select widget.
class EnumArrayField extends StatefulWidget {
  /// Creates an enum array field; null [onChanged] renders it read-only.
  const EnumArrayField({
    required this.fieldState,
    required this.onChanged,
    required this.displayContext,
    required this.handlerRegistry,
    required this.readOnly,
    this.title,
    this.error,
    this.helpText,
    super.key,
  });

  /// The state to render; its enumOptions supply the checkbox rows.
  final ArrayFieldState fieldState;

  /// Receives the new element list after a toggle; null disables the field.
  final void Function(List<JsonListFieldEntry>)? onChanged;

  /// The group title.
  final String? title;

  /// Validation message; replaces [helpText] while non-empty.
  final String? error;

  /// Helper text under the title.
  final String? helpText;

  /// Where the field sits (dialog depth, header visibility).
  final FieldDisplayContext displayContext;

  /// The registry the toggled-on element states are built through.
  final JsonHandlerRegistry handlerRegistry;

  /// Disables the checkboxes without disabling the group frame.
  final bool readOnly;

  @override
  State<EnumArrayField> createState() => _EnumArrayFieldState();
}

class _EnumArrayFieldState extends State<EnumArrayField> {
  bool _isLoading = false;

  Future<void> _onChanged({
    required bool? value,
    required Object? enumValue,
  }) async {
    if (_isLoading || widget.onChanged == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final itemSchema = widget.fieldState.itemsSchemaForEnum;

      final curValues = widget.fieldState.children.map((c) => c.state.valueOrNull).toList(growable: false);
      final currentIndex = deepIndexOf(curValues, enumValue);

      final newChildren = widget.fieldState.children.toList();
      if (value == false) {
        if (currentIndex == -1 || currentIndex >= newChildren.length) return;

        newChildren.removeAt(currentIndex);
      } else {
        if (currentIndex != -1) return;

        final newFieldState = await widget.handlerRegistry.withValidationContext(
          itemSchema: itemSchema,
          rootSchema: widget.fieldState.rootSchema,
          body: (validationContext) => widget.handlerRegistry.buildStateOrUndefined(
            FieldBuildRequest(
              value: PresenceValue(enumValue),
              errors: const [],
              schemaSource: SchemaWithContext.maybe(itemSchema, validationContext),
              title: itemSchema?.title,
              resolveContext: widget.displayContext.child(newChildren.length.toString()),
              readOnly: widget.readOnly,
            ),
          ),
        );

        newChildren.add(JsonListFieldEntry(state: newFieldState, additional: true));
      }
      if (!mounted) return;
      widget.onChanged?.call(newChildren);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.fieldState.enumOptions ?? const <EnumOption>[];
    final enumValues = options.map((o) => o.value).toList(growable: false);

    final canEdit = widget.onChanged != null && !_isLoading && !widget.readOnly;

    final curValues = widget.fieldState.children.map((c) => c.state.valueOrNull).toList(growable: false);

    // Values present in the JSON but not listed in the enum must stay visible
    // (together with their validation errors) and removable; otherwise the
    // document would silently hold data the user can neither see nor fix.
    final extraValues = curValues.where((v) => deepIndexOf(enumValues, v) == -1).toList(growable: false);
    final allValues = [...enumValues, ...extraValues];

    final theme = Theme.of(context);
    final errorLoc = widget.error;
    final helpTextLoc = widget.helpText;

    // Same frame mechanics as the expanded framed EditorGroup: inside
    // InputDecorator both the floating label and the content are positioned
    // from contentPadding.start, so the frame and its label are drawn by a
    // childless decorator stretched behind the content, while the checkbox
    // list lays itself out with no horizontal inset. Help text and errors
    // move inside the frame (an errorText below the border would overlap
    // the stacked content).
    final list = ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 190),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: allValues.length,
        itemBuilder: (context, index) {
          final enumValue = allValues[index];
          final isExtra = index >= enumValues.length;

          final childIndex = deepIndexOf(curValues, enumValue);
          final isChecked = childIndex != -1;
          final errors = isChecked ? widget.fieldState.children[childIndex].state.errors?.map((e) => e.details).nonNulls.join('\n') : null;

          return CheckboxListTile(
            value: isChecked,
            // Unchecking an extra value removes it for good: with no enum
            // entry to re-add it from, it simply leaves the list.
            onChanged: canEdit
                ? (value) => _onChanged(
                    enumValue: enumValue,
                    value: value,
                  )
                : null,
            title: Text(
              isExtra ? enumValue.toString() : options[index].label,
              style: isExtra ? const TextStyle(fontStyle: FontStyle.italic) : null,
            ),
            secondary: isExtra
                ? Tooltip(
                    message: jsonFormLocalizationsOf(context).notAllowedByEnumError,
                    child: Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error),
                  )
                : null,
            subtitle: errors != null && errors.isNotEmpty
                ? Text(
                    errors,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  )
                : null,
          );
        },
      ),
    );

    final field = Stack(
      children: [
        Positioned.fill(
          child: InputDecorator(
            expands: true,
            decoration: InputDecoration(
              border: FormTheme.groupBorderOf(context),
              // Indents only the label, following the horizontal
              // contentPadding of the app theme.
              contentPadding: FormTheme.groupLabelPaddingOf(context),
              label: FieldLabel(
                label: widget.title,
                isRequired: widget.fieldState.fieldAnnotations?.required ?? false,
              ),
            ),
            child: const SizedBox.shrink(),
          ),
        ),
        // Breathing room between the frame line and the rows.
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (helpTextLoc != null)
                Padding(
                  padding: FormTheme.fieldPaddingOf(context),
                  child: Text(helpTextLoc, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
              if (errorLoc != null && errorLoc.isNotEmpty) ErrorsPanel(errors: [errorLoc]),
              list,
            ],
          ),
        ),
      ],
    );

    return Padding(
      padding: FormTheme.of(context).fieldPadding,
      child: field,
    );
  }
}
