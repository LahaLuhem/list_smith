/// @docImport '../models/paging_state.dart';
library;

import 'package:meta/meta.dart';

/// Which surface an async list shows, read off its [PagingState].
@internal
enum PagingStatus() {
  /// No page yet and none failed, so the 1st one is on its way.
  loadingFirstPage,

  /// Nothing to show, and the last fetch threw.
  firstPageError,

  /// Every loaded page came back empty.
  noItemsFound,

  /// Rows to show, and more may follow.
  ongoing,

  /// Rows to show, and the next page threw.
  subsequentPageError,

  /// Rows to show, and the source has no more.
  completed,
}
