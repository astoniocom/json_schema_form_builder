import 'package:form_foundation/form_foundation.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../../models/json_field_state.dart';

/// One property of an ObjectFieldState: the child's state plus whether the
/// property is additional (not declared in the schema's `properties`, so it
/// is removable and renamable).
class ObjectFieldEntry extends MapFieldEntry<JsonFieldState> {
  /// Creates an entry around [state].
  const ObjectFieldEntry({
    required super.state,
    required this.additional,
  });

  /// True when the property is governed by `additionalProperties` or
  /// `patternProperties` rather than declared in `properties`.
  final bool additional;

  /// This entry with the child's value removed (see JsonFieldState.clear).
  ObjectFieldEntry clear() {
    return ObjectFieldEntry(
      additional: additional,
      state: state.clear(),
    );
  }

  /// This entry with [errors] stored into the child state (see
  /// JsonFieldState.applyErrors).
  ObjectFieldEntry applyErrors(List<ValidationError> errors) {
    return ObjectFieldEntry(
      additional: additional,
      state: state.applyErrors(errors),
    );
  }

  /// Whether the child failed validation.
  bool get hasErrors => state.hasErrors;
}
