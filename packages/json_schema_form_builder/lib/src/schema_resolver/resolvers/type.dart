import '../models/exceptions.dart';
import '../models/schema_key_merge_stragegy.dart';
import '../models/schema_merge_context.dart';

/// `type` — intersection of allowed types.
///
/// Handles `String` (single type) and `List<String>` (union) in any combination.
/// Throws [SchemaMergeException] when the intersection is empty.
class TypeStrategy implements SchemaKeyMergeStrategy {
  /// Creates the strategy.
  const TypeStrategy();

  @override
  bool canHandle(String key, dynamic aValue, dynamic bValue) => key == 'type';

  @override
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  ) {
    final aTypes = _normalise(key, aValue);
    final bTypes = _normalise(key, bValue);
    final intersection = aTypes.intersection(bTypes);

    if (intersection.isEmpty) {
      throw SchemaMergeException(
        key: key,
        message: "type conflict: '$aValue' ∩ '$bValue' = ∅ — schema is unsatisfiable",
      );
    }

    // Keep the compact form when possible.
    return intersection.length == 1 ? intersection.first : intersection.toList();
  }

  static Set<String> _normalise(String key, dynamic value) {
    if (value is String) return {value};
    if (value is List) return Set<String>.from(value);
    throw SchemaMergeException(
      key: key,
      message: 'unexpected value for "type": $value',
    );
  }
}
