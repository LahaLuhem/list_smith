import 'dart:async';

/// Collapses a fast-changing search query into one committed value.
///
/// Moves the committed query on once the debounce elapses, or next tick for [Duration.zero]. Trims,
/// and does nothing when the trimmed value hasn't changed.
///
/// [onCommitted] only ever runs from the timer, never during `build`, so a `setState` in it is safe.
class QueryDebouncer {
  /// Called with the new committed, trimmed query once a scheduled change elapses.
  final void Function(String committedQuery) onCommitted;

  var _committedQuery = '';
  Timer? _timer;

  /// Creates it.
  new({required this.onCommitted});

  /// The current committed (trimmed) query.
  String get committedQuery => _committedQuery;

  /// Sets the 1st committed query without scheduling or notifying. Call once from `initState`.
  void seed(String query) => _committedQuery = query.trim();

  /// Commits [query] after [debounce], or next tick for [Duration.zero]. Does nothing when the trimmed
  /// value already matches.
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
