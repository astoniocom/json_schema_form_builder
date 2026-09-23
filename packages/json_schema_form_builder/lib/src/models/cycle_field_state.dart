import 'package:json_schema_builder/json_schema_builder.dart';

import 'json_field_state.dart';
import 'presence_value.dart';

/// The state of a field collapsed by the registry's cycle guard: its schema
/// is a `$ref` whose target was already expanded on the descent from the
/// root (`FieldResolveContext.expandedRefs`) and it carries no value, so
/// expanding it eagerly would recurse forever (`node -> next -> node -> …`).
///
/// Built directly by JsonHandlerRegistry.buildState (not selected by schema
/// dispatch); rendered by CycleFieldHandler as a collapsed row with an
/// "Expand" button. Expansion rebuilds the real state with this field's
/// [ref] removed from [expandedRefs] — one click reveals exactly one more
/// level, the repeat below collapses again.
///
/// [JsonFieldState.schema] here is deliberately the RAW (unresolved) schema
/// — the `{$ref: …}` map with its local siblings: expansion needs to run the
/// full pipeline from scratch, and the guard fires before resolution.
class CycleFieldState extends JsonFieldState {
  /// Creates a collapsed cycle state; built by the registry's guard.
  const CycleFieldState({
    required super.value,
    required super.rootSchema,
    required this.expandedRefs,
    super.schema,
    super.title,
    super.fieldAnnotations,
    super.errors,
  }) : super(variants: null);

  /// Snapshot of `FieldResolveContext.expandedRefs` at guard time (includes
  /// [ref] — that is why the guard fired).
  final Set<String> expandedRefs;

  /// The repeated `$ref` this field stands for.
  String get ref => schema?.value[r'$ref'] as String? ?? '';

  /// [variants] and [matchedVariantIndices] are ignored: a collapsed cycle
  /// state never carries alternatives (see the constructor).
  @override
  CycleFieldState rebuild({
    required PresenceValue<dynamic> value,
    required Set<int> matchedVariantIndices,
    required List<JsonFieldState>? variants,
    required List<ValidationError>? errors,
  }) {
    return CycleFieldState(
      value: value,
      rootSchema: rootSchema,
      expandedRefs: expandedRefs,
      schema: schema,
      title: title,
      fieldAnnotations: fieldAnnotations,
      errors: errors,
    );
  }
}
