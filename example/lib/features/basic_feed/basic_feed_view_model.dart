import 'package:pmvvm/pmvvm.dart';

import '../core/data/models/demo_item.dart';
import '../core/repos/demo_repository.dart';

/// Backs the Basic feed demo: it just hands the repository's paged fetch to
/// `ListSmith.async`, which owns all the paging + refresh state itself.
final class BasicFeedViewModel extends ViewModel {
  final _repository = DemoRepository();

  Future<List<DemoItem>> fetchPage(int pageIndex, int pageSize) =>
      _repository.fetchPage(pageIndex, pageSize);
}
