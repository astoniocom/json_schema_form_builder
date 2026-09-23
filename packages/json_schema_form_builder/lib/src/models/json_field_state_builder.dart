import 'field_build_request.dart';
import 'json_field_state.dart';
import 'presence_value.dart';

/// The domain half of a field handler: everything the state-building pipeline
/// (JsonHandlerRegistry.buildState and friends) needs, and nothing the UI
/// needs. Deliberately free of Flutter types (no Widget/BuildContext), so the
/// Json -> State -> Json pipeline can be exercised and faked without widgets.
///
/// JsonFieldHandler implements both this and JsonFieldRenderer; the split
/// is a compile-time seam, not a physical one -- a concrete handler is still
/// one class. See also `field_with_variants.dart` for the presentation-side
/// composition that used to live on the handler base class.
abstract interface class JsonFieldStateBuilder<FS extends JsonFieldState> {
  /// Builds the field state from [request], already fully enriched by the
  /// registry pipeline: schema resolved ($ref/allOf), fieldAnnotations
  /// computed, anyOf/oneOf variant states built and matched
  /// (FieldBuildRequest.variants / matchedVariantIndices) — the builder only
  /// maps the request onto its state type.
  ///
  /// Must not modify the input value: Json -> State -> Json is an identity
  /// (absent stays absent, `[]`/`{}` are preserved, type-mismatched values
  /// are kept as is). defaultValue/emptyValue apply only on user interaction.
  Future<FS> buildState(FieldBuildRequest request);

  /// Capability: whether this editor can edit [value] (a decoded JSON
  /// value; null means a JSON null). Consulted where an already-chosen
  /// handler meets a concrete value: the seed check in
  /// JsonHandlerRegistry.buildStateForNewField, and the entry dialog's
  /// value carry-over and null-submit gates.
  ///
  /// NOT used for handler selection: which handler serves which type is
  /// registry wiring (see JsonHandlerRegistration), so a fallback editor
  /// may honestly return true for everything without competing in
  /// type-based dispatch.
  bool canEditValue(dynamic value);

  /// Whether this handler produced (and therefore can render/rebuild) the
  /// given state.
  bool matchesState(JsonFieldState state);

  /// The empty JSON representation of this handler's field type (`""`, `{}`,
  /// `[]`), or null when the type has no empty representation (e.g. a
  /// number). See JsonFieldHandler.canonicalEmptyValue for the write-policy
  /// discussion.
  PresenceValue<dynamic>? get canonicalEmptyValue;
}
