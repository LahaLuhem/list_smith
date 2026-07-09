/// @docImport 'pagination_end_policy.dart';
library;

/// Fetches one page of items for an async list.
///
/// `pageIndex` is 0-based (the first page is `0`); `pageSize` is the page size configured on the list.
/// Returns the page's items as any `Iterable`, which list_smith materialises exactly once at the boundary,
/// so a lazy `.map()` / `.where()` or a `Set` is fine without a trailing `.toList()`.
///
/// V1 returns items only: no `hasMore` flag and no search query. End-of-data is decided by the injected
/// [PaginationEndPolicy] (by default, the first empty page), not by anything this callback returns.
/// A misbehaving endpoint (for example a 404 past the last page) is the callback's job to catch and
/// turn into an empty page.
typedef PageFetcher<T extends Object> = Future<Iterable<T>> Function(int pageIndex, int pageSize);
