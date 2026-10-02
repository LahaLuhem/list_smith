/// @docImport '../models/paging_state.dart';
library;

/// Which surface an async list shows, read off its [PagingState].
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
