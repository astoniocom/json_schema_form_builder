import '../models/schema_key_merge_stragegy.dart';
import '../models/schema_merge_context.dart';

/// `$defs` / `definitions` — same per-key recursive merge as `properties`.
class DefsStrategy implements SchemaKeyMergeStrategy {
  /// Creates the strategy.
  const DefsStrategy();

  static const _keys = {r'$defs', 'definitions'};

  @override
  bool canHandle(String key, dynamic aValue, dynamic bValue) => _keys.contains(key) && aValue is Map<String, dynamic> && bValue is Map<String, dynamic>;

  @override
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  ) =>
      // Reuse the recursive helper from PropertiesStrategy.
      context.mergeMapsRecursively(
        aValue as Map<String, dynamic>,
        bValue as Map<String, dynamic>,
      );
}
