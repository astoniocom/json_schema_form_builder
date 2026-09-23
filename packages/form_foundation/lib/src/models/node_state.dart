/// A child slot of a [NodeState]: wraps the child's state so implementations
/// can extend the entry with per-child metadata (see ObjectFieldEntry in
/// json_schema_form_builder).
class MapFieldEntry<FS> {
  /// Creates an entry around [state].
  const MapFieldEntry({
    required this.state,
  });

  /// The child field's state.
  final FS state;
}

/// A container state exposing its children as a keyed map: what a container
/// widget needs to render the child fields and to badge itself when any of
/// them failed validation ([childrenHasErrors]).
abstract class NodeState<K, FS> {
  /// Whether any child failed validation. Containers surface this on their
  /// collapsed representation, where child errors are otherwise invisible.
  bool get childrenHasErrors;

  /// The child fields, keyed the way the container addresses them.
  Map<K, MapFieldEntry<FS>> get children;
}
