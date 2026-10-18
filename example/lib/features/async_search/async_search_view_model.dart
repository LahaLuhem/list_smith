import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:listenable_collections/listenable_collections.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/mixins/failure_injection_mixin.dart';
import '/features/core/mixins/search_query_mixin.dart';
import '/features/core/repos/demo_repository.dart';

final class AsyncSearchViewModel() extends ViewModel with SearchQueryMixin, FailureInjectionMixin {
  static const _maxLoggedEvents = 50;

  final _repository = DemoRepository();
  final _shouldKeepCacheNotifier = ValueNotifier(false);
  final _eventsNotifier = ListNotifier<String>();

  late final observer = _EventLogObserver(_record);

  ValueListenable<bool> get shouldKeepCacheListenable => _shouldKeepCacheNotifier;

  ValueListenable<List<String>> get eventsListenable => _eventsNotifier;

  Future<List<DemoItem>> fetchPage(PageRequest request) =>
      withInjectedFailures(_repository.fetchPage(request.pageIndex, request.pageSize));

  Future<List<DemoItem>> searchFetchPage(SearchPageRequest request) => withInjectedFailures(
    _repository.searchFetchPage(request.query, request.pageIndex, request.pageSize),
  );

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onKeepCacheToggled({required bool value}) => _shouldKeepCacheNotifier.value = value;

  void clearLog() => _eventsNotifier.clear();

  void _record(String event) {
    _eventsNotifier.insert(0, event);
    if (_eventsNotifier.length > _maxLoggedEvents) _eventsNotifier.removeLast();
  }

  @override
  void dispose() {
    _shouldKeepCacheNotifier.dispose();
    _eventsNotifier.dispose();

    super.dispose();
  }
}

final class _EventLogObserver(final void Function(String event) _record) extends ListSmithObserver {
  @override
  void onPageLoaded(int pageIndex, int itemCount, {required bool isSearchMode}) =>
      _record('onPageLoaded  page $pageIndex · $itemCount items${isSearchMode ? ' · search' : ''}');

  @override
  void onError(Exception exception, StackTrace stackTrace) => _record('onError  $exception');

  @override
  void onReload(FetchTrigger trigger) => _record('onReload  ${trigger.name}');

  @override
  void onQueryCommitted(String query) =>
      _record(query.isEmpty ? 'onQueryCommitted  (cleared)' : 'onQueryCommitted  "$query"');

  @override
  void onSearchModeChanged({required bool isSearchMode}) =>
      _record('onSearchModeChanged  ${isSearchMode ? 'entered search' : 'left search'}');
}
