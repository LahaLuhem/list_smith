/// @docImport '../models/pagination_end_policy.dart';
library;

/// Fetches one page of items for an async list.
///
/// `pageIndex` is 0-based (the first page is `0`); `pageSize` is the page size configured on the list.
/// The returned `Iterable` is materialised exactly once by list_smith at the boundary, so a lazy
/// `.map()` / `.where()` or a `Set` is fine without a trailing `.toList()`.
///
/// Returns items only: end-of-data is decided by the injected [PaginationEndPolicy] (by default, the
/// first empty page), not by anything this fetcher returns. A misbehaving endpoint (for example a 404
/// past the last page) is the fetcher's job to catch and turn into an empty page.
final class PageFetcher<T extends Object> {
  final Future<Iterable<T>> Function(int pageIndex, int pageSize) _fetch;

  /// Wraps a function returning one page of items for a 0-based `pageIndex` and the list's `pageSize`.
  const PageFetcher(this._fetch);

  /// Fetches the page at [pageIndex] with the given [pageSize].
  Future<Iterable<T>> call(int pageIndex, int pageSize) => _fetch(pageIndex, pageSize);
}
