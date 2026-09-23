import '../models/schema_key_merge_stragegy.dart';
import '../models/schema_merge_context.dart';

/// `allOf` / `anyOf` / `oneOf` — concatenation of both lists.
class CompositionKeyStrategy implements SchemaKeyMergeStrategy {
  /// Creates the strategy.
  const CompositionKeyStrategy();
  static const _keys = {'allOf', 'anyOf', 'oneOf'};

  @override
  bool canHandle(String key, dynamic aValue, dynamic bValue) => _keys.contains(key) && aValue is List && bValue is List;

  @override
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  ) => [...(aValue as List), ...(bValue as List)];
}
