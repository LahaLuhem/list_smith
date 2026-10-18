import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/mixins/search_query_mixin.dart';
import '/features/core/repos/demo_repository.dart';

final class SyncSearchViewModel() extends ViewModel with SearchQueryMixin {
  final _repository = DemoRepository();

  List<DemoItem> get items => _repository.items;
}
