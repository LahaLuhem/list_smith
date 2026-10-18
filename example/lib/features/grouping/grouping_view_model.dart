import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/mixins/search_query_mixin.dart';
import '/features/core/repos/demo_repository.dart';

const _categories = ['Alpha', 'Beta', 'Gamma'];

final class GroupingViewModel() extends ViewModel with SearchQueryMixin {
  final _repository = DemoRepository();

  List<DemoItem> get items => _repository.items;

  /// Typed concretely so `Grouping.by` infers `K` instead of widening it to `Object`.
  String categoryOf(DemoItem item) => _categories[item.id % _categories.length];
}
