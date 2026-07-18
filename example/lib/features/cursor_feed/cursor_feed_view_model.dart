import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Cursor feed demo: it forwards the cursor the previous page returned to the repository's
/// cursor-driven fetch, which returns the next slice and the cursor after it. `list_smith` owns the
/// paging state and hands each page's returned cursor back as `previousSignal`.
final class CursorFeedViewModel extends ViewModel {
  final _repository = DemoRepository();

  Future<(List<DemoItem>, Object?)> cursorFetchPage(int _, int pageSize, Object? cursor) =>
      _repository.cursorFetchPage(cursor, pageSize);
}
