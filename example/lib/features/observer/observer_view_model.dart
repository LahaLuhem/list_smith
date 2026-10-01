import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:listenable_collections/listenable_collections.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

final class ObserverViewModel extends ViewModel {
  static const _maxLoggedEvents = 50;

  final _repository = DemoRepository();
  final _queryNotifier = ValueNotifier('');
  final _shouldInjectFailuresNotifier = ValueNotifier(false);
  final _eventsNotifier = ListNotifier<String>();

  late final observer = _EventLogObserver(_record);

  ValueListenable<String> get queryListenable => _queryNotifier;

  ValueListenable<bool> get shouldInjectFailuresListenable => _shouldInjectFailuresNotifier;

  ValueListenable<List<String>> get eventsListenable => _eventsNotifier;

  Future<List<DemoItem>> fetchPage(PageRequest request) async {
    final page = await _repository.fetchPage(request.pageIndex, request.pageSize);
    if (_shouldInjectFailuresNotifier.value) throw Exception('Simulated network failure');

    return page;
  }

  Future<List<DemoItem>> searchFetchPage(SearchPageRequest request) async {
    final page = await _repository.searchFetchPage(
      request.query,
      request.pageIndex,
      request.pageSize,
    );
    if (_shouldInjectFailuresNotifier.value) throw Exception('Simulated network failure');

    return page;
  }

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onQueryChanged(String value) => _queryNotifier.value = value;

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onInjectFailuresToggled({required bool value}) =>
      _shouldInjectFailuresNotifier.value = value;

  void clearLog() => _eventsNotifier.clear();

  void _record(String event) {
    _eventsNotifier.insert(0, event);
    if (_eventsNotifier.length > _maxLoggedEvents) _eventsNotifier.removeLast();
  }

  @override
  void dispose() {
    _queryNotifier.dispose();
    _shouldInjectFailuresNotifier.dispose();
    _eventsNotifier.dispose();

    super.dispose();
  }
}

final class _EventLogObserver extends ListSmithObserver {
  final void Function(String event) _record;

  new(this._record);

  @override
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) =>
      _record('onPageLoaded  page $pageIndex · $itemCount items${isSearchMode ? ' · search' : ''}');

  @override
  void onError(Object error, StackTrace stackTrace) => _record('onError  $error');

  @override
  void onReload(FetchTrigger trigger) => _record('onReload  ${trigger.name}');

  @override
  void onQueryCommitted(String query) =>
      _record(query.isEmpty ? 'onQueryCommitted  (cleared)' : 'onQueryCommitted  "$query"');

  @override
  void onSearchModeChanged({required bool isSearchMode}) =>
      _record('onSearchModeChanged  ${isSearchMode ? 'entered search' : 'left search'}');
}
