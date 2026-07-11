import 'dart:async';

/// Collapses a rapidly-changing search query into a single committed value.
///
/// Both sync and async search take a live `query` that the consumer changes on every keystroke-driven
/// rebuild; this advances the committed query only after the caller's debounce elapses (or the next
/// event-loop tick when the debounce is [Duration.zero]). The query is trimmed, and a change that
/// leaves the committed value unchanged is a no-op.
///
/// The owner seeds the initial query in `initState` (which commits at once, no timer) and schedules
/// each later change. [onCommitted] only ever runs from the timer, never during `build`, so a
/// `setState` inside it is safe; cancelling in `dispose` stops a pending commit from firing after the
/// widget is gone.
class QueryDebouncer {
  /// Called with the new committed, trimmed query once a scheduled change elapses.
  final void Function(String committedQuery) onCommitted;

  var _committedQuery = '';
  Timer? _timer;

  /// Creates a debouncer that reports each committed query to [onCommitted].
  QueryDebouncer({required this.onCommitted});

  /// The current committed (trimmed) query.
  String get committedQuery => _committedQuery;

  /// Sets the initial committed query without scheduling or notifying; call once from `initState`.
  void seed(String query) => _committedQuery = query.trim();

  /// Debounces [query]: commits it after [debounce] (or the next tick when [Duration.zero]), unless
  /// the trimmed value already matches the committed query, in which case it is a no-op.
  void schedule(String query, Duration debounce) {
    final trimmedQuery = query.trim();
    if (trimmedQuery == _committedQuery) return;

    _timer?.cancel();
    _timer = Timer(debounce, () {
      _committedQuery = trimmedQuery;
      onCommitted(trimmedQuery);
    });
  }

  /// Cancels any pending commit; call from the owner's `dispose`.
  void dispose() => _timer?.cancel();
}
