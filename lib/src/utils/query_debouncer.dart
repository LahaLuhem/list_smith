import 'dart:async';

/// Collapses a rapidly-changing search query into a single committed value.
///
/// Advances the committed query once the caller's debounce elapses, or on the next tick when it is
/// [Duration.zero]. Trims, and no-ops when the trimmed value hasn't changed.
///
/// The owner seeds in `initState` and schedules every later change. [onCommitted] only ever runs
/// from the timer, never during `build`, so a `setState` inside it is safe.
class QueryDebouncer {
  /// Called with the new committed, trimmed query once a scheduled change elapses.
  final void Function(String committedQuery) onCommitted;

  var _committedQuery = '';
  Timer? _timer;

  /// Creates a debouncer that reports each committed query to [onCommitted].
  new({required this.onCommitted});

  /// The current committed (trimmed) query.
  String get committedQuery => _committedQuery;

  /// Sets the initial committed query without scheduling or notifying. Call once from `initState`.
  void seed(String query) => _committedQuery = query.trim();

  /// Commits [query] after [debounce], or the next tick when [Duration.zero]. A no-op when the
  /// trimmed value already matches.
  void schedule(String query, Duration debounce) {
    final trimmedQuery = query.trim();
    if (trimmedQuery == _committedQuery) return;

    _timer?.cancel();
    _timer = Timer(debounce, () {
      _committedQuery = trimmedQuery;
      onCommitted(trimmedQuery);
    });
  }

  /// Cancels any pending commit. Call from the owner's `dispose`.
  void dispose() => _timer?.cancel();
}
