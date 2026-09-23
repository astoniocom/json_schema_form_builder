import '../schema_merger.dart';

/// Exposes recursive merging to strategies without coupling them to [SchemaMerger].
abstract interface class SchemaMergeContext {
  /// Merges two schema fragments through the full strategy chain.
  Map<String, dynamic> mergeSchemas(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  );

  /// Merges two plain maps key by key, recursing into map values; scalars
  /// from [b] win.
  Map<String, dynamic> mergeMapsRecursively(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  );
}
