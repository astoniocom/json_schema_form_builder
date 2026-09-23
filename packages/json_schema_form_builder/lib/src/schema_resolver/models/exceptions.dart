/// Thrown by the schema merger when two fragments produce an unsatisfiable
/// result (e.g. `type: string` merged with `type: number`).
class SchemaMergeException implements Exception {
  /// Creates the exception for the keyword [key].
  const SchemaMergeException({required this.key, required this.message});

  /// The schema keyword whose merge failed.
  final String key;

  /// What made the merge unsatisfiable.
  final String message;

  @override
  String toString() => 'SchemaMergeException at key "$key": $message';
}
