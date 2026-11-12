import 'dart:async';

import 'package:flutter/foundation.dart';

/// Commits a search query once it settles, typed or from code: trimmed, and empty under
/// `minSearchLength`. The list holds what's committed.
///
/// Commits only ever run from the timer, never during `build`, so a `setState` in one is safe.
@internal
class QueryDebouncer({
  /// Called with the new committed query once a typed change elapses.
  required final ValueChanged<String> onCommitted,
}) {
  Timer? _timer;

  /// The commit from code on its way, with its text before the gate and its waiting caller.
  ({String trimmedQuery, Completer<void> doneCompleter})? _pendingCodeCommit;

  /// Creates it.
  this;

  /// Commits typed [query] after [debounce], or next tick for [Duration.zero]. Does nothing when it
  /// would commit [committedQuery] again, or shows the commit from code on its way.
  void schedule(
    String query,
    Duration debounce, {
    required int minSearchLength,
    required String committedQuery,
  }) {
    final trimmedQuery = query.trim();
    if (trimmedQuery == _pendingCodeCommit?.trimmedQuery) return;

    // Before the return below, so a query typed back to the committed one drops what's on its way.
    cancel();
    final searchQuery = _gate(trimmedQuery, minSearchLength: minSearchLength);
    // The trimmed text too, so a field showing a short search committed from code holds.
    if (committedQuery == trimmedQuery || committedQuery == searchQuery) return;

    _timer = Timer(debounce, () => onCommitted(searchQuery));
  }

  /// Commits [query] from code after [debounce], the committed one again too, since each call is its
  /// own event. Under [minSearchLength] it's no search, as typed.
  ///
  /// Completes with what [onCommitted] returns, or as soon as anything replaces it.
  Future<void> scheduleFromCode(
    String query,
    Duration debounce, {
    required int minSearchLength,
    required String committedQuery,
    required AsyncValueSetter<String> onCommitted,
  }) {
    final trimmedQuery = query.trim();
    final searchQuery = _gate(trimmedQuery, minSearchLength: minSearchLength);
    cancel();
    if (searchQuery.isEmpty && committedQuery.isEmpty) return Future.syncValue(null);

    final doneCompleter = Completer<void>();
    _pendingCodeCommit = (trimmedQuery: trimmedQuery, doneCompleter: doneCompleter);
    _timer = Timer(debounce, () {
      _pendingCodeCommit = null;
      doneCompleter.complete(onCommitted(searchQuery));
    });

    return doneCompleter.future;
  }

  /// Cancels what's on its way, letting a caller waiting on it go. Call from the owner's `dispose`
  /// too.
  void cancel() {
    _timer?.cancel();
    _pendingCodeCommit?.doneCompleter.complete();
    _pendingCodeCommit = null;
  }

  /// [query] as it would commit. A list seeds its 1st query with it.
  static String searchQueryOf(String query, {required int minSearchLength}) =>
      _gate(query.trim(), minSearchLength: minSearchLength);

  static String _gate(String trimmedQuery, {required int minSearchLength}) =>
      trimmedQuery.length < minSearchLength ? '' : trimmedQuery;
}
