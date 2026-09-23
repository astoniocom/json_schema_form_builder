import '../models/schema_key_merge_stragegy.dart';
import '../models/schema_merge_context.dart';

/// `properties` — per-key recursive merge.
///
/// If both schemas define the same property key, their sub-schemas are merged
/// recursively rather than overwritten.
class PropertiesStrategy implements SchemaKeyMergeStrategy {
  /// Creates the strategy.
  const PropertiesStrategy();

  @override
  bool canHandle(String key, dynamic aValue, dynamic bValue) => key == 'properties' && aValue is Map<String, dynamic> && bValue is Map<String, dynamic>;

  @override
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  ) => context.mergeMapsRecursively(
    aValue as Map<String, dynamic>,
    bValue as Map<String, dynamic>,
  );
}
