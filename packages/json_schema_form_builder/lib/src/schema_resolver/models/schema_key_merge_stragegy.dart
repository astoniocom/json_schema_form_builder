import 'schema_merge_context.dart';

/// Strategy for a single JSON Schema key.
abstract interface class SchemaKeyMergeStrategy {
  /// Returns `true` when this strategy owns the given [key]/value combination.
  bool canHandle(String key, dynamic aValue, dynamic bValue);

  /// Produces the merged value.
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  );
}
