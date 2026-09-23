import '../models/schema_key_merge_stragegy.dart';
import '../models/schema_merge_context.dart';

/// Fallback: `b` unconditionally overwrites `a`.
///
/// Must always be registered **last** in the strategy list.
class FallbackOverwriteStrategy implements SchemaKeyMergeStrategy {
  /// Creates the strategy.
  const FallbackOverwriteStrategy();

  @override
  bool canHandle(String key, dynamic aValue, dynamic bValue) => true;

  @override
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  ) => bValue;
}
