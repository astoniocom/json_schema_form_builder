import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';

import '../l10n/json_form_localizations.dart';
import '../models/field_context.dart';
import '../models/json_field_state.dart';
import '../models/json_handler_registry.dart';
import '../models/schema_values.dart';

/// The anyOf/oneOf selector: a dropdown of the state's variants plus the
/// selected alternative's editor below it. The live selection is owned here
/// (the state's matchedVariantIndices is only the initial value — see the
/// contract on JsonFieldState).
class VariantSwitcher extends StatefulWidget {
  /// Creates a variant switcher; null [onChanged] renders it read-only.
  const VariantSwitcher({
    required this.fieldState,
    required this.handlerRegistry,
    required this.displayContext,
    required this.onChanged,
    this.onVariantSwitched,
    super.key,
  });

  /// The state whose variants are offered.
  final JsonFieldState fieldState;

  /// The registry the alternative's editor is rendered through.
  final JsonHandlerRegistry handlerRegistry;

  /// Where the field sits (dialog depth, header visibility).
  final FieldDisplayContext displayContext;

  /// An edit inside the selected alternative: its index and new state; null
  /// disables the switcher.
  final void Function(int, JsonFieldState)? onChanged;

  /// Called with the previous and the picked alternative's indices when the
  /// user switches. The old index is null when nothing was selected before
  /// (the value matched no alternative).
  final void Function(int?, int)? onVariantSwitched;

  @override
  State<VariantSwitcher> createState() => _VariantSwitcherState();
}

class _VariantSwitcherState extends State<VariantSwitcher> {
  /// Null when nothing was selected yet (the value matched no alternative).
  late int? _selectedVariantIndex = widget.fieldState.matchedVariantIndices.firstOrNull;

  /// The user interacted with this switcher (picked an alternative or edited
  /// the selected alternative's field), so rebuilds caused by those edits
  /// must not yank the selection to another matching alternative. Reset when
  /// the value is replaced from outside (see [_localEditPending]): a stale
  /// user choice must not override the new document.
  bool _isEdited = false;

  /// Set when a change leaves through [VariantSwitcher.onChanged] or
  /// [VariantSwitcher.onVariantSwitched]; cleared on the next widget update.
  /// Distinguishes the echo of this widget's own write (the parent rebuilds
  /// the state with the value just emitted) from an external value
  /// replacement (e.g. the app swapped the document), which unlocks
  /// [_isEdited] so the selection follows the new value again.
  bool _localEditPending = false;

  void _setBestVariant() {
    final variants = widget.fieldState.variants;
    if (variants == null || variants.isEmpty) {
      _selectedVariantIndex = null;
      _isEdited = false;
      return;
    }

    final selectedVariantIndexLoc = _selectedVariantIndex;
    if (selectedVariantIndexLoc == null || selectedVariantIndexLoc >= variants.length) {
      // No forced pre-selection: when the value matches no alternative the
      // dropdown stays empty (hint) until the user picks one, so picking any
      // alternative — including the first — fires the switch and writes the
      // value.
      _selectedVariantIndex = widget.fieldState.matchedVariantIndices.firstOrNull;
      _isEdited = false;
    }
  }

  @override
  void didUpdateWidget(covariant VariantSwitcher oldWidget) {
    final isExternalChange = !_localEditPending && widget.fieldState.value != oldWidget.fieldState.value;
    _localEditPending = false;
    if (isExternalChange) _isEdited = false;

    _setBestVariant();

    final selectedVariantIndexLoc = _selectedVariantIndex;
    if (!_isEdited && widget.fieldState.matchedVariantIndices.isNotEmpty && !widget.fieldState.matchedVariantIndices.contains(selectedVariantIndexLoc)) {
      _selectedVariantIndex = widget.fieldState.matchedVariantIndices.first;
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.fieldState.variants ?? [];
    final selectedVariantIndexLoc = _selectedVariantIndex;
    final selectedVariant = selectedVariantIndexLoc == null ? null : variants.elementAtOrNull(selectedVariantIndexLoc);
    final onChangedLoc = widget.onChanged;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (variants.isNotEmpty)
          Padding(
            padding: FormTheme.fieldPaddingOf(context),
            // isExpanded lets long option labels ellipsize instead of
            // overflowing the form, and the IntrinsicWidth around it shrinks
            // the button back to its content so it does not greedily take the
            // full width when the labels are short.
            child: IntrinsicWidth(
              child: DropdownButton<int>(
                isExpanded: true,
                value: selectedVariantIndexLoc,
                hint: Text(jsonFormLocalizationsOf(context).selectOptionLabel),
                items: variants
                    .mapIndexed((index, state) {
                      return DropdownMenuItem(
                        value: index,
                        // 1-based, matching how alternatives are numbered in
                        // schema documentation and RJSF.
                        child: Text(
                          state.title ?? jsonFormLocalizationsOf(context).variantLabel(index + 1),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    })
                    .toList(growable: false),
                onChanged: !(widget.fieldState.fieldAnnotations?.readOnly ?? false) && widget.onChanged != null
                    ? (newIndex) {
                        if (newIndex == null) return;

                        _localEditPending = true;
                        widget.onVariantSwitched?.call(selectedVariantIndexLoc, newIndex);
                        setState(() {
                          _isEdited = true;
                          _selectedVariantIndex = newIndex;
                        });
                      }
                    : null,
              ),
            ),
          ),

        // A pinned alternative (const or single-element enum) is fully
        // determined by the selection itself: rendering its read-only field
        // below the switcher would only duplicate the dropdown (matches
        // react-jsonschema-form, where a oneOf/anyOf of constants is just a
        // select).
        if (selectedVariant != null && selectedVariantIndexLoc != null && !schemaPinnedValue(selectedVariant.schema).present)
          widget.handlerRegistry
              .handlerForField(selectedVariant)
              .buildField(
                context: context,
                fieldState: selectedVariant,
                displayContext: widget.displayContext.resetDisplay().withoutHeader(),
                onChanged: onChangedLoc == null || (widget.fieldState.fieldAnnotations?.readOnly ?? false)
                    ? null
                    : (state) {
                        _localEditPending = true;
                        onChangedLoc(selectedVariantIndexLoc, state);
                        _isEdited = true;
                      },
              ),
      ],
    );
  }
}
