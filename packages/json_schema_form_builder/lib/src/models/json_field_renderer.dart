import 'package:flutter/widgets.dart';

import 'field_context.dart';
import 'json_field_state.dart';

/// The presentation half of a field handler: renders a state built by the
/// JsonFieldStateBuilder counterpart. UI consumers (the form tree, the
/// Variant switcher, the entry dialog's "Value type" picker) depend on this
/// contract; the state-building pipeline never does.
abstract interface class JsonFieldRenderer<FS extends JsonFieldState> {
  /// Builds the editor for [fieldState]; [onChanged] receives a NEW state on
  /// every edit (states are immutable), null renders the field read-only.
  Widget buildField({
    required BuildContext context,
    required FS fieldState,
    required FieldDisplayContext displayContext,
    void Function(JsonFieldState)? onChanged,
  });

  /// Human-readable type name shown in type pickers ("String", "Object").
  /// [context] is deliberately part of the signature even though current
  /// implementations ignore it: display names are user-facing strings, and
  /// localizing them (Localizations.of) must not be a breaking change.
  String typeDisplayName(BuildContext context);
}
