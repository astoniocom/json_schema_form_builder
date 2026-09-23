import 'package:form_foundation/form_foundation.dart';

import '../models/exceptions.dart';
import '../models/schema_key_merge_stragegy.dart';
import '../models/schema_merge_context.dart';

/// `enum` — intersection (only values that appear in *both* lists).
class EnumIntersectionStrategy implements SchemaKeyMergeStrategy {
  /// Creates the strategy.
  const EnumIntersectionStrategy();

  @override
  bool canHandle(String key, dynamic aValue, dynamic bValue) => key == 'enum' && aValue is List && bValue is List;

  @override
  dynamic merge(
    String key,
    dynamic aValue,
    dynamic bValue,
    SchemaMergeContext context,
  ) {
    final a = aValue as List;
    final b = bValue as List;

    final intersection = a.where((itemA) => b.any((itemB) => deepEquals(itemA, itemB))).toList();

    if (intersection.isEmpty) {
      throw SchemaMergeException(
        key: key,
        message: 'enum intersection is empty — merged schema is unsatisfiable',
      );
    }

    return intersection;
  }
}
