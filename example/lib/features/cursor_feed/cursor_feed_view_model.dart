import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/repos/demo_repository.dart';

/// Backs the Cursor feed demo, forwarding `previousSignal` to the repository's cursor-driven fetch,
/// which returns the next slice plus the cursor after it.
final class CursorFeedViewModel extends ViewModel {
  final _repository = DemoRepository();

  Future<(List<DemoItem>, Object?)> cursorFetchPage(PageRequest request) =>
      _repository.cursorFetchPage(request.previousSignal, request.pageSize);
}
