import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:listenable_collections/listenable_collections.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Observer demo: a searchable `ListSmith.async` wired to a `ListSmithObserver` that records
/// every lifecycle event into a live log, plus an inject-failure toggle so the error event can be
/// exercised on demand.
final class ObserverViewModel extends ViewModel {
  /// Cap on the log so it can't grow without bound; the newest events are kept.
  static const _maxLoggedEvents = 50;

  final _repository = DemoRepository();
  final _queryNotifier = ValueNotifier('');
  final _shouldInjectFailuresNotifier = ValueNotifier(false);
  final _events = ListNotifier<String>();

  /// The observer handed to `ListSmith.async`; records each event into [eventsListenable].
  late final observer = _EventLogObserver(_record);

  /// The live search query, driven by the search field.
  ValueListenable<String> get queryListenable => _queryNotifier;

  /// Whether the next fetch should fail, so the observer's `onError` can be seen.
  ValueListenable<bool> get shouldInjectFailuresListenable => _shouldInjectFailuresNotifier;

  /// The recorded observer events, newest first.
  ValueListenable<List<String>> get eventsListenable => _events;

  Future<List<DemoItem>> fetchPage(int pageIndex, int pageSize) async {
    final page = await _repository.fetchPage(pageIndex, pageSize);
    if (_shouldInjectFailuresNotifier.value) throw Exception('Simulated network failure');

    return page;
  }

  Future<List<DemoItem>> searchFetchPage(String query, int pageIndex, int pageSize) async {
    final page = await _repository.searchFetchPage(query, pageIndex, pageSize);
    if (_shouldInjectFailuresNotifier.value) throw Exception('Simulated network failure');

    return page;
  }

  // A setter can't be torn off as the search field's onChanged callback.
  // ignore: use_setters_to_change_properties
  void onQueryChanged(String value) => _queryNotifier.value = value;

  // A setter can't be torn off as the switch's onChanged callback.
  // ignore: use_setters_to_change_properties
  void onInjectFailuresToggled({required bool value}) =>
      _shouldInjectFailuresNotifier.value = value;

  /// Empties the event log.
  void clearLog() => _events.clear();

  void _record(String event) {
    _events.insert(0, event);
    if (_events.length > _maxLoggedEvents) _events.removeLast();
  }

  @override
  void dispose() {
    _queryNotifier.dispose();
    _shouldInjectFailuresNotifier.dispose();
    _events.dispose();

    super.dispose();
  }
}

/// A [ListSmithObserver] that formats each event into a log line and hands it to [_record].
final class _EventLogObserver extends ListSmithObserver {
  final void Function(String event) _record;

  _EventLogObserver(this._record);

  @override
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) =>
      _record('onPageLoaded  page $pageIndex · $itemCount items${isSearchMode ? ' · search' : ''}');

  @override
  void onError(Object error, StackTrace stackTrace) => _record('onError  $error');

  @override
  void onRefresh() => _record('onRefresh');

  @override
  void onQueryCommitted(String query) =>
      _record(query.isEmpty ? 'onQueryCommitted  (cleared)' : 'onQueryCommitted  "$query"');

  @override
  void onSearchModeChanged({required bool isSearchMode}) =>
      _record('onSearchModeChanged  ${isSearchMode ? 'entered search' : 'left search'}');
}
