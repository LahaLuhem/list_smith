import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/mixins/search_query_mixin.dart';
import '/features/core/repos/demo_repository.dart';

final class AsyncSearchViewModel() extends ViewModel with SearchQueryMixin {
  final _repository = DemoRepository();
  final _shouldKeepCacheNotifier = ValueNotifier(false);

  ValueListenable<bool> get shouldKeepCacheListenable => _shouldKeepCacheNotifier;

  Future<List<DemoItem>> fetchPage(PageRequest request) =>
      _repository.fetchPage(request.pageIndex, request.pageSize);

  Future<List<DemoItem>> searchFetchPage(SearchPageRequest request) =>
      _repository.searchFetchPage(request.query, request.pageIndex, request.pageSize);

  // Torn off as an onChanged callback, so it can't be a setter.
  // ignore: use_setters_to_change_properties
  void onKeepCacheToggled({required bool value}) => _shouldKeepCacheNotifier.value = value;

  @override
  void dispose() {
    _shouldKeepCacheNotifier.dispose();

    super.dispose();
  }
}
