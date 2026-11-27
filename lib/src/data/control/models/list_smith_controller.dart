/// @docImport '/src/data/observer/observer.dart';
/// @docImport '/src/data/pagination/pagination.dart';
/// @docImport '/src/data/refresh/refresh.dart';
/// @docImport '/src/widgets/list_smith.dart';
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '/src/data/search/search.dart';
import '/src/utils/tripwire.dart';
import 'list_smith_controller_host.dart';

/// Drives a [ListSmith.async] list from code: a refresh button, a tab re-tap, a re-read after a local
/// write, a logout, a scan.
///
/// Intents only, never the pager or its state. Want to hear about events instead? That's [ListSmithObserver].
///
/// With no list attached, a verb does nothing, a save waits for the next list, and [search] asserts
/// if none ever attached. Nothing to dispose.
class ListSmithController<T extends Object>() {
  ListSmithControllerHost<T>? _host;
  final _attachTripwire = Tripwire();
  final _heldSaves = <_HeldSave<T>>[];

  /// Creates it.
  this;

  /// Reloads exactly as a pull would, running the configured [Reload] ([ResetToFirstPage] when the list
  /// has no pull). While searching, it reloads the search.
  ///
  /// Completes once its fresh data shows or its fetch fails. Joins a refresh already running. During
  /// another reload or a 1st-page load, it completes with that one and runs once more after.
  Future<void> refresh() => _host?.refresh() ?? Future<void>.syncValue(null);

  /// Re-reads every loaded page in place, keeping the user's scroll position, because your data changed
  /// locally. Pages report [FetchTrigger.invalidated].
  ///
  /// Completes once the re-read is over. During a reload or a 1st-page load, it completes with that one
  /// and re-reads once more after, so a write landing mid-read isn't missed.
  Future<void> invalidate() => _host?.invalidate() ?? Future<void>.syncValue(null);

  /// Starts the list over from page 0: a logout, an account switch, a filter outside search. That page
  /// reports [FetchTrigger.invalidated]. Drops every draft, even one waiting for its list.
  ///
  /// Cuts in on whatever load is running rather than joining it, and completes once its page 0 is over.
  /// Keeps a search, its fetcher included, so it restarts, and a feed held by [KeepCachePolicy] starts
  /// over once the search ends.
  Future<void> reset() {
    _heldSaves.clear(); // like the list's own drafts, so a logout never shows the last account's

    return _host?.reset() ?? Future<void>.syncValue(null);
  }

  /// Searches [query] like typing it, through [fetchPage] or the search's own fetcher. The list's
  /// debounce and min length apply unless passed. Needs an attached list with an [AsyncSearch].
  ///
  /// A repeat runs too, so a failed lookup can be retried. Completes once its page 0 is over, or as
  /// soon as something replaces it while it waits.
  Future<void> search(
    String query, {
    SearchPageFetcher<T>? fetchPage,
    Duration? searchDebounce,
    int? minSearchLength,
  }) {
    assert(query.trim().isNotEmpty, 'search() needs a query. To go back, call endSearch().');
    assert(
      _host != null || _attachTripwire.hasTripped,
      'Pass this ListSmithController to ListSmith.async before calling search().',
    );

    return _host?.search(
          query,
          fetchPage: fetchPage,
          searchDebounce: searchDebounce,
          minSearchLength: minSearchLength,
        ) ??
        Future<void>.syncValue(null);
  }

  /// Ends a [search], waiting or showing, and lands on what the list's query holds, as typed.
  /// Completes once its page 0 is over, or at once when that already shows.
  Future<void> endSearch() => _host?.endSearch() ?? Future<void>.syncValue(null);

  /// Shows [item] wherever a copy with its id is loaded, or at the top of the feed if none is. For
  /// a change that's already true on your server or store, and lasts until those pages are read again.
  void upsert(T item) => _host?.upsert(item);

  /// Hides every loaded copy of [item] by its id, until those pages are read again.
  void remove(T item) => _host?.remove(item);

  /// [upsert] before your server has it: [draft] shows until [commit] answers, then the answer does. On
  /// failure the draft goes and [onFailure] gets the exception, so nothing throws. The id can't change.
  /// With no list attached, it waits for the next one.
  Future<void> upsertAsync(
    T draft, {
    required Future<T> commit,
    ValueSetter<Exception>? onFailure,
  }) =>
      _host?.upsertAsync(draft, commit: commit, onFailure: onFailure) ??
      _holdUntilAnswered(
        commit,
        onFailure,
        (host) => host.upsertAsync(draft, commit: commit, onFailure: onFailure),
      );

  /// [remove] before your server has it. On failure the item comes back and [onFailure] gets the
  /// exception. With no list attached, it waits for the next one.
  Future<void> removeAsync(
    T item, {
    required Future<void> commit,
    ValueSetter<Exception>? onFailure,
  }) =>
      _host?.removeAsync(item, commit: commit, onFailure: onFailure) ??
      _holdUntilAnswered(
        commit,
        onFailure,
        (host) => host.removeAsync(item, commit: commit, onFailure: onFailure),
      );

  /// Binds this controller to the list it drives, which takes over the saves held meanwhile. One
  /// controller, one list.
  @internal
  @nonVirtual
  void attach(ListSmithControllerHost<T> host) {
    assert(
      _host == null,
      'A ListSmithController drives one list, and this one is already attached.',
    );
    _host = host;
    _attachTripwire.trip();
    for (final heldSave in _heldSaves) {
      heldSave.handOverTo(host);
    }
    _heldSaves.clear();
  }

  /// Unbinds the list, leaving this controller inert. Called when that list is disposed.
  @internal
  @nonVirtual
  void detach() => _host = null;

  /// A list attaching while the save is out takes it over.
  Future<void> _holdUntilAnswered(
    Future<Object?> commit,
    ValueSetter<Exception>? onFailure,
    AsyncValueSetter<ListSmithControllerHost<T>> handOver,
  ) {
    final heldSave = _HeldSave(handOver);
    _heldSaves.add(heldSave);
    unawaited(heldSave.answer(commit, onFailure).whenComplete(() => _heldSaves.remove(heldSave)));

    return heldSave.doneFuture;
  }
}

/// A save made with no list attached, until it answers or a list takes it over.
final class _HeldSave<T extends Object>(
  /// Makes the same call on the list taking it over, which answers it from then on.
  final AsyncValueSetter<ListSmithControllerHost<T>> _handOver,
) {
  final _doneCompleter = Completer<void>();

  /// Completes once it's answered, here or by the list that took it over.
  Future<void> get doneFuture => _doneCompleter.future;

  bool get _isHandedOver => _doneCompleter.isCompleted;

  void handOverTo(ListSmithControllerHost<T> host) => _doneCompleter.complete(_handOver(host));

  /// With no list taking it over, there's nothing to roll back, only a failure to pass on.
  Future<void> answer(Future<Object?> commit, ValueSetter<Exception>? onFailure) async {
    try {
      await commit;
      if (!_isHandedOver) _doneCompleter.complete();
    } on Exception catch (exception) {
      if (_isHandedOver) return;
      onFailure?.call(exception);
      _doneCompleter.complete();
    } on Object catch (error, stackTrace) {
      // A bug in the save, so it goes on to the caller, or comes from the list that took it over.
      if (!_isHandedOver) _doneCompleter.completeError(error, stackTrace);
    }
  }
}
