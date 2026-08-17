import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Async search demo: a paginated normal feed that switches to a paginated search when the
/// query is non-empty, with a live toggle between the two `SearchCachePolicy` cases.
final class AsyncSearchViewModel extends ViewModel {
  final _repository = DemoRepository();
  final _queryNotifier = ValueNotifier('');
  final _keepCacheNotifier = ValueNotifier(false);

  /// The live search query, driven by the search field.
  ValueListenable<String> get queryListenable => _queryNotifier;

  /// Whether to keep and restore the normal feed across a search (`KeepCachePolicy`) rather than
  /// reload it (the default `ReplaceCachePolicy`).
  ValueListenable<bool> get keepCacheListenable => _keepCacheNotifier;

  Future<List<DemoItem>> fetchPage(PageRequest request) =>
      _repository.fetchPage(request.pageIndex, request.pageSize);

  Future<List<DemoItem>> searchFetchPage(SearchPageRequest request) =>
      _repository.searchFetchPage(request.query, request.pageIndex, request.pageSize);

  // A setter can't be torn off as the search field's onChanged callback.
  // ignore: use_setters_to_change_properties
  void onQueryChanged(String value) => _queryNotifier.value = value;

  // A setter can't be torn off as the switch's onChanged callback.
  // ignore: use_setters_to_change_properties
  void onKeepCacheToggled({required bool value}) => _keepCacheNotifier.value = value;

  @override
  void dispose() {
    _queryNotifier.dispose();
    _keepCacheNotifier.dispose();

    super.dispose();
  }
}
