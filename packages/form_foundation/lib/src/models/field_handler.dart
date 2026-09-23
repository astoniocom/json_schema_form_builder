import 'package:flutter/material.dart';

/// The minimal contract of a field renderer: given an immutable field state
/// [FS], build the editor widget. Schema-agnostic — json_schema_form_builder
/// layers its JsonFieldHandler on top.
///
/// Type parameters: [FS] — the concrete state this handler renders; [V] —
/// the state type emitted through onChanged (a base type shared by all
/// handlers of a registry); [E] — the display context passed down the widget
/// tree.
abstract class FieldHandler<FS, V, E> {
  /// Const constructor for subclasses.
  const FieldHandler();

  /// Builds the editor for [fieldState]. [onChanged] receives a NEW state on
  /// every user edit (states are immutable); null renders the field
  /// read-only.
  Widget buildField({
    required BuildContext context,
    required FS fieldState,
    required E displayContext,
    void Function(V)? onChanged,
  });
}
