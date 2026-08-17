import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Basic feed demo: it just hands the repository's paged fetch to
/// `ListSmith.async`, which owns all the paging + refresh state itself.
final class BasicFeedViewModel extends ViewModel {
  final _repository = DemoRepository();

  Future<List<DemoItem>> fetchPage(PageRequest request) =>
      _repository.fetchPage(request.pageIndex, request.pageSize);
}
