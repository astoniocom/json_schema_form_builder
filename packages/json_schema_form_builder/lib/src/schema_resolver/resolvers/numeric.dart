import '../models/schema_key_merge_stragegy.dart';
import '../models/schema_merge_context.dart';

/// Numeric / size constraints — most-restrictive value wins.
///
/// | Key family | Strategy         |
/// |------------|------------------|
/// | min-*      | `max(a, b)`      |
/// | max-*      | `min(a, b)`      |
class NumericConstraintStrategy implements SchemaKeyMergeStrategy {
  /// Creates the strategy.
  const NumericConstraintStrategy();
  static const _minKeys = {
    'minimum',
    'exclusiveMinimum',
    'minLength',
    'minItems',
    'minProperties',
  };

  static const _maxKeys = {
    'maximum',
    'exclusiveMaximum',
    'maxLength',
    'maxItems',
    'maxProperties',
  };

  @override
  bool canHandle(String key, dynamic aValue, dynamic bValue) => (_minKeys.contains(key) || _maxKeys.contains(key)) && aValue is num && bValue is num;

  @override
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  ) {
    final a = aValue as num;
    final b = bValue as num;
    // For lower bounds, the higher value is more restrictive.
    // For upper bounds, the lower value is more restrictive.
    return _minKeys.contains(key) ? (a > b ? a : b) : (a < b ? a : b);
  }
}
