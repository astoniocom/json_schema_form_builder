import '../models/schema_key_merge_stragegy.dart';
import '../models/schema_merge_context.dart';

/// Generic nested-object merge: recursively merge any two sub-schemas.
///
/// This handles keys like `if`, `then`, `else`, `not`, `items`, etc.
class NestedSchemaStrategy implements SchemaKeyMergeStrategy {
  /// Creates the strategy.
  const NestedSchemaStrategy();

  @override
  bool canHandle(String key, dynamic aValue, dynamic bValue) => aValue is Map<String, dynamic> && bValue is Map<String, dynamic>;

  @override
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  ) => context.mergeSchemas(
    aValue as Map<String, dynamic>,
    bValue as Map<String, dynamic>,
  );
}
