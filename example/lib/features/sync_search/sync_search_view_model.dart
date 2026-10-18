import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/mixins/search_query_mixin.dart';
import '/features/core/repos/demo_repository.dart';

/// Cycled per row, so the raw list interleaves them and grouping has something to do.
const _categories = ['Alpha', 'Beta', 'Gamma'];

final class SyncSearchViewModel() extends ViewModel with SearchQueryMixin {
  final _repository = DemoRepository();
  final _shouldGroupNotifier = ValueNotifier(false);

  List<DemoItem> get items => _repository.items;

  ValueListenable<bool> get shouldGroupListenable => _shouldGroupNotifier;

  /// Typed concretely so `Grouping.by` infers `K` instead of widening it to `Object`.
  String categoryOf(DemoItem item) => _categories[item.id % _categories.length];

  // A handler named like the rest, called from the switch's onChanged.
  // ignore: use_setters_to_change_properties
  void onGroupToggled({required bool value}) => _shouldGroupNotifier.value = value;

  @override
  void dispose() {
    _shouldGroupNotifier.dispose();

    super.dispose();
  }
}
