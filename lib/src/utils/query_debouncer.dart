import 'dart:async';

import 'package:flutter/foundation.dart';

/// Collapses a fast-changing search query into one committed value: trimmed, and empty when shorter
/// than `minSearchLength`, so the committed query is the one that searches.
///
/// [onCommitted] only ever runs from the timer, never during `build`, so a `setState` in it is safe.
@internal
class QueryDebouncer({
  /// Called with the new committed query once a scheduled change elapses.
  required final ValueChanged<String> onCommitted,
}) {
  var _committedQuery = '';
  Timer? _timer;

  /// Creates it.
  this;

  /// The current committed query.
  String get committedQuery => _committedQuery;

  /// Sets the 1st committed query without scheduling or notifying. Call once from `initState`.
  void seed(String query, {required int minSearchLength}) =>
      _committedQuery = _searchQueryOf(query, minSearchLength);

  /// Commits [query] after [debounce], or next tick for [Duration.zero]. Does nothing when it would
  /// commit the query already committed.
  void schedule(String query, Duration debounce, {required int minSearchLength}) {
    final searchQuery = _searchQueryOf(query, minSearchLength);
    // Before the early return, so a query typed back to the committed one drops what's on its way.
    _timer?.cancel();
    if (searchQuery == _committedQuery) return;

    _timer = Timer(debounce, () {
      _committedQuery = searchQuery;
      onCommitted(searchQuery);
    });
  }

  /// Cancels any pending commit. Call from the owner's `dispose`.
  void dispose() => _timer?.cancel();

  static String _searchQueryOf(String query, int minSearchLength) {
    final trimmedQuery = query.trim();

    return trimmedQuery.length < minSearchLength ? '' : trimmedQuery;
  }
}
