import 'dart:async';

import 'package:flutter/foundation.dart';

/// Commits a search query once it settles: trimmed, and empty under `minSearchLength`. The list
/// holds what's committed.
///
/// [onCommitted] only ever runs from the timer, never during `build`, so a `setState` in it is safe.
@internal
class QueryDebouncer({
  /// Called with the new committed query once a scheduled change elapses.
  required final ValueChanged<String> onCommitted,
}) {
  Timer? _timer;

  /// Creates it.
  this;

  /// Commits [query] after [debounce], or next tick for [Duration.zero]. Does nothing when it would
  /// commit [committedQuery] again.
  void schedule(
    String query,
    Duration debounce, {
    required int minSearchLength,
    required String committedQuery,
  }) {
    final searchQuery = searchQueryOf(query, minSearchLength: minSearchLength);
    // Before the early return, so a query typed back to the committed one drops what's on its way.
    _timer?.cancel();
    if (searchQuery == committedQuery) return;

    _timer = Timer(debounce, () => onCommitted(searchQuery));
  }

  /// Cancels any pending commit. Call from the owner's `dispose`.
  void dispose() => _timer?.cancel();

  /// [query] as it would commit. A list seeds its 1st query with it.
  static String searchQueryOf(String query, {required int minSearchLength}) {
    final trimmedQuery = query.trim();

    return trimmedQuery.length < minSearchLength ? '' : trimmedQuery;
  }
}
