import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/json_form_localizations.dart';
import '../../models/field_context.dart';
import '../../models/json_field_state.dart';
import '../../models/presence_value.dart';
import 'enum_field_state.dart';

/// The editor of select-like fields: a dropdown listing the state's
/// enumValues (with a "not selected" entry when the field is optional).
class EnumField extends StatefulWidget {
  /// Creates an enum field; null [onChanged] renders it read-only.
  const EnumField({
    required this.fieldState,
    required this.displayContext,
    required this.onChanged,
    super.key,
  });

  /// The state to render.
  final EnumFieldState fieldState;

  /// Where the field sits (dialog depth, header visibility).
  final FieldDisplayContext displayContext;

  /// Receives the updated state; null disables the field. Deliberately wide
  /// (the base state type): the widget only emits states, and the emitted
  /// copy is statically a JsonFieldState (see JsonFieldState.copyWith).
  final void Function(JsonFieldState)? onChanged;

  @override
  State<EnumField> createState() => _EnumFieldState();
}

class _EnumFieldState extends State<EnumField> {
  final TextEditingController _enumController = TextEditingController();

  /// The PresenceValue for which [_enumController] was last updated.
  /// The comparison is done on the PresenceValue itself (it already has correct
  /// deep-equality via deepEquals — see PresenceValue.==), not on .toString(),
  /// to avoid depending on formatting and touching .value in the absent state.
  late PresenceValue<dynamic> _syncedValue;

  late List<Object?> _syncedEnumValues;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The labels below come from Localizations (a dependency), so the initial
    // sync lives here instead of initState, and re-runs on a locale change.
    _setupEnum();
  }

  String _labelForEnumValue(Object? value) => value?.toString() ?? jsonFormLocalizationsOf(context).enumNullOptionLabel;

  String get _absentLabel => jsonFormLocalizationsOf(context).enumNotSelectedLabel;

  /// Converts [value] to the text displayed in the controller. A single
  /// formatting point for both branches (the value is found among enumValues /
  /// not found), so that the comparison in [didUpdateWidget] does not fire
  /// falsely because of different formatting of the same value.
  String _displayTextFor(PresenceValue<dynamic> value) {
    if (!value.present) return _absentLabel;
    if (value.valueOrNull == null) return _labelForEnumValue(null);

    final enumValuesLoc = widget.fieldState.enumValues;
    final index = deepIndexOf(enumValuesLoc, value.value);
    final displayValue = index != -1 ? enumValuesLoc[index] : value.value;
    return _labelForEnumValue(displayValue);
  }

  void _setupEnum() {
    final value = widget.fieldState.value;
    _enumController.text = _displayTextFor(value);
    _syncedValue = value;
    _syncedEnumValues = widget.fieldState.enumValues;
  }

  @override
  void didUpdateWidget(covariant EnumField oldWidget) {
    super.didUpdateWidget(oldWidget);

    final valueChanged = widget.fieldState.value != _syncedValue;
    final enumValuesChanged = !deepEquals(widget.fieldState.enumValues, _syncedEnumValues);

    if (valueChanged || enumValuesChanged) {
      _setupEnum();
    }
  }

  @override
  void dispose() {
    _enumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enumValues = widget.fieldState.enumValues;
    final isReadOnly = (widget.fieldState.fieldAnnotations?.readOnly ?? false) || widget.onChanged == null || enumValues.isEmpty;

    final field = DropdownMenu<PresenceValue<dynamic>>(
      controller: _enumController,
      requestFocusOnTap: false,
      enableSearch: false,
      searchCallback: (_, __) => null,
      decorationBuilder: (context, controller) {
        return InputDecoration(
          label: FieldLabel(
            label: widget.fieldState.title ?? jsonFormLocalizationsOf(context).selectOptionLabel,
            isRequired: widget.fieldState.fieldAnnotations?.required ?? false,
          ),
          errorText: widget.fieldState.errorsAsString,
          helperText: widget.fieldState.fieldAnnotations?.description,
          // Replaces DropdownMenu's built-in trailing button: that one is
          // wrapped in a non-configurable Padding(4) which makes the field
          // taller than other fields in dense themes and shifts the arrow
          // off-center. A plain IconButton suffix gets exactly the same
          // geometry as the suffix icons of the other fields.
          suffixIcon: ExcludeSemantics(
            child: IconButton(
              isSelected: controller.isOpen,
              icon: const Icon(Icons.arrow_drop_down),
              selectedIcon: const Icon(Icons.arrow_drop_up),
              onPressed: isReadOnly ? null : () => controller.isOpen ? controller.close() : controller.open(),
            ),
          ),
        );
      },
      expandedInsets: EdgeInsets.zero,
      enabled: !isReadOnly,
      onSelected: isReadOnly
          ? null
          : (PresenceValue<dynamic>? value) {
              if (value == null) return;
              widget.onChanged?.call(widget.fieldState.copyWith(value: value));
            },
      dropdownMenuEntries: [
        DropdownMenuEntry(value: const PresenceValue.absent(), label: _absentLabel),
        ...enumValues.map(
          (v) => DropdownMenuEntry(
            value: PresenceValue(v),
            label: _labelForEnumValue(v),
          ),
        ),
      ],
    );

    return Padding(
      padding: FormTheme.fieldPaddingOf(context),
      child: field,
    );
  }
}
