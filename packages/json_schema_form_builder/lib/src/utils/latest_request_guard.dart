/// Guard for the "latest request wins" async pattern.
///
/// Widgets that rebuild state asynchronously previously hand-rolled the
/// request-id bookkeeping (`final id = ++_requestId; ...await...;
/// if (id != _requestId) return;`), which is easy to get wrong — e.g.
/// incrementing before an early return silently cancels requests that should
/// survive. This class owns the bookkeeping: results of superseded runs are
/// discarded instead of overwriting newer state.
class LatestRequestGuard {
  /// Creates a guard; [_isAlive] adds a liveness check (e.g. `() => mounted`).
  LatestRequestGuard({this._isAlive});

  /// Extra liveness check consulted before applying a result,
  /// e.g. `() => mounted` for a State.
  final bool Function()? _isAlive;

  int _requestId = 0;

  /// Runs [task] and passes its result to [apply], unless a newer run started
  /// (or [cancelPending] was called) while [task] was awaited, or [_isAlive]
  /// returns false.
  Future<void> run<T>(Future<T> Function() task, void Function(T result) apply) async {
    final requestId = ++_requestId;
    final result = await task();
    if (requestId != _requestId || !(_isAlive?.call() ?? true)) return;
    apply(result);
  }

  /// Invalidates in-flight runs without starting a new one: their results
  /// will be discarded.
  void cancelPending() => _requestId++;
}
