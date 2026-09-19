import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Async search demo: a paginated feed that switches to a paginated search on a non-empty
/// query, with a live toggle between the 2 `SearchCachePolicy` cases.
final class AsyncSearchViewModel extends ViewModel {
  final _repository = DemoRepository();
  final _queryNotifier = ValueNotifier('');
  final _keepCacheNotifier = ValueNotifier(false);

  /// The live search query, driven by the search field.
  ValueListenable<String> get queryListenable => _queryNotifier;

  /// Keep and restore the feed across a search (`KeepCachePolicy`) rather than reload it.
  ValueListenable<bool> get keepCacheListenable => _keepCacheNotifier;

  Future<List<DemoItem>> fetchPage(PageRequest request) =>
      _repository.fetchPage(request.pageIndex, request.pageSize);

  Future<List<DemoItem>> searchFetchPage(SearchPageRequest request) =>
      _repository.searchFetchPage(request.query, request.pageIndex, request.pageSize);

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onQueryChanged(String value) => _queryNotifier.value = value;

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onKeepCacheToggled({required bool value}) => _keepCacheNotifier.value = value;

  @override
  void dispose() {
    _queryNotifier.dispose();
    _keepCacheNotifier.dispose();

    super.dispose();
  }
}
