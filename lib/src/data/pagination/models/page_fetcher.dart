/// @docImport 'end_context.dart';
/// @docImport 'pagination_end_policy.dart';
library;

/// Fetches one page of items for an async list.
///
/// `pageIndex` is 0-based (the first page is `0`); `pageSize` is the page size configured on the list.
/// The returned `Iterable` is materialised exactly once by list_smith at the boundary, so a lazy
/// `.map()` / `.where()` or a `Set` is fine without a trailing `.toList()`.
///
/// Build one with [PageFetcher.new] to return items only, leaving end-of-data to the injected
/// [PaginationEndPolicy] (by default, the first empty page). Build one with [PageFetcher.withSignal]
/// to also report an end signal the policy can read from [EndContext.lastPageSignal] (for example a
/// `hasMore` flag or a next-cursor). A misbehaving endpoint (for example a 404 past the last page) is
/// the fetcher's job to catch and turn into an empty page.
final class PageFetcher<T extends Object> {
  final Future<(Iterable<T>, Object?)> Function(int pageIndex, int pageSize) _fetch;

  /// Whether this fetcher reports an end signal, i.e. it was built with [PageFetcher.withSignal].
  final bool reportsSignal;

  /// Wraps a function returning one page of items; end-of-data is left to the [PaginationEndPolicy].
  factory PageFetcher(Future<Iterable<T>> Function(int pageIndex, int pageSize) fetch) =>
      PageFetcher._(
        (pageIndex, pageSize) async => (await fetch(pageIndex, pageSize), null),
        reportsSignal: false,
      );

  const PageFetcher._(this._fetch, {required this.reportsSignal});

  /// Wraps a function returning one page of items alongside an end signal (for example a `hasMore`
  /// flag or a next-cursor), surfaced to the end policy as [EndContext.lastPageSignal].
  factory PageFetcher.withSignal(
    Future<(Iterable<T>, Object?)> Function(int pageIndex, int pageSize) fetch,
  ) => PageFetcher._(fetch, reportsSignal: true);

  /// Fetches the page at [pageIndex] with [pageSize], as its items and an optional end signal.
  Future<(Iterable<T>, Object?)> call(int pageIndex, int pageSize) => _fetch(pageIndex, pageSize);
}
