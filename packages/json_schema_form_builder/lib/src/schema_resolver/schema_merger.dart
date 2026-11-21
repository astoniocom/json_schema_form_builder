// schema_merger.dart
//
// JSON Schema merge implementation.
//
// Design:
//  • SchemaMerger          — orchestrator; iterates over keys and delegates to strategies
//  • SchemaKeyMergeStrategy — one strategy per semantics; add new behaviour
//                             without touching existing code (OCP)
//  • SchemaMergeContext    — interface passed to every strategy so it can
//                             trigger recursive merges without knowing the merger
//  • SchemaMergeException  — thrown when schemas produce an unsatisfiable result

import 'models/schema_key_merge_stragegy.dart';
import 'models/schema_merge_context.dart';
import 'resolvers/composition.dart';
import 'resolvers/defs.dart';
import 'resolvers/enum.dart';
import 'resolvers/fallback.dart';
import 'resolvers/nested.dart';
import 'resolvers/numeric.dart';
import 'resolvers/properties.dart';
import 'resolvers/required.dart';
import 'resolvers/type.dart';

/// Merges JSON Schema fragments (`allOf` branches, a `$ref` target with its
/// local siblings) key by key, delegating each keyword to the first
/// SchemaKeyMergeStrategy that accepts it.
class SchemaMerger implements SchemaMergeContext {
  /// Creates a merger with an explicit strategy chain; most callers use
  /// [SchemaMerger.withDefaults].
  const SchemaMerger({required this._strategies});

  /// Builds a merger pre-loaded with all built-in strategies.
  ///
  /// Pass [extraStrategies] to insert custom strategies **before** the
  /// fallback without touching this factory.
  factory SchemaMerger.withDefaults({
    List<SchemaKeyMergeStrategy> extraStrategies = const [],
  }) => SchemaMerger(
    strategies: [
      const PropertiesStrategy(),
      const DefsStrategy(),
      const RequiredStrategy(),
      const EnumIntersectionStrategy(),
      const CompositionKeyStrategy(),
      const NumericConstraintStrategy(),
      const TypeStrategy(),
      const NestedSchemaStrategy(),
      ...extraStrategies,
      const FallbackOverwriteStrategy(), // always last
    ],
  );

  final List<SchemaKeyMergeStrategy> _strategies;

  @override
  Map<String, dynamic> mergeSchemas(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final result = <String, dynamic>{...a};

    for (final entry in b.entries) {
      final key = entry.key;
      final bValue = entry.value;

      if (!result.containsKey(key)) {
        result[key] = bValue;
        continue;
      }

      final aValue = result[key];
      result[key] = _strategyFor(key, aValue, bValue).merge(
        key,
        aValue,
        bValue,
        this,
      );
    }

    return result;
  }

  SchemaKeyMergeStrategy _strategyFor(
    String key,
    dynamic aValue,
    dynamic bValue,
  ) => _strategies.firstWhere((s) => s.canHandle(key, aValue, bValue));

  @override
  Map<String, dynamic> mergeMapsRecursively(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    final result = <String, dynamic>{...a};

    for (final entry in b.entries) {
      final existing = result[entry.key];
      result[entry.key] = (existing is Map<String, dynamic> && entry.value is Map<String, dynamic>)
          ? mergeSchemas(existing, entry.value as Map<String, dynamic>)
          : entry.value;
    }

    return result;
  }
}
