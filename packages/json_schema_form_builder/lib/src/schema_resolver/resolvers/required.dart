import '../models/schema_key_merge_stragegy.dart';
import '../models/schema_merge_context.dart';

/// `required` — set union (no duplicates, order preserved from a then b).
class RequiredStrategy implements SchemaKeyMergeStrategy {
  /// Creates the strategy.
  const RequiredStrategy();

  @override
  bool canHandle(String key, dynamic aValue, dynamic bValue) => key == 'required' && aValue is List && bValue is List;

  @override
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  ) => <dynamic>{...(aValue as List), ...(bValue as List)}.toList();
}
