/// @docImport '/src/data/pagination/models/end_context.dart';
/// @docImport '/src/data/pagination/models/page_fetcher.dart';
library;

import 'search_page_request.dart';

/// Fetches one page of search results for an async list, given the [SearchPageRequest] describing it.
///
/// Parallels [PageFetcher] but its request carries the committed [SearchPageRequest.query]; the
/// returned `Iterable` is materialised once by list_smith at the boundary.
///
/// Build one with [SearchPageFetcher.new] for items only, or [SearchPageFetcher.withSignal] to also
/// report an end signal for the end policy (see [EndContext.lastPageSignal]); with `withSignal` the
/// signal reaches the next search fetch as [SearchPageRequest.previousSignal], so a cursor-driven
/// search fetches the next page from the cursor the previous one returned.
final class SearchPageFetcher<T extends Object> {
  final Future<(Iterable<T>, Object?)> Function(SearchPageRequest request) _fetch;

  /// Whether this fetcher reports an end signal, i.e. it was built with [SearchPageFetcher.withSignal].
  final bool reportsSignal;

  /// Wraps a function returning one page of results for the request's query and page.
  factory(Future<Iterable<T>> Function(SearchPageRequest request) fetch) =>
      SearchPageFetcher._((request) async => (await fetch(request), null), reportsSignal: false);

  const new _(this._fetch, {required this.reportsSignal});

  /// Wraps a function returning results with a new end signal, surfaced as
  /// [EndContext.lastPageSignal] and handed to the next fetch as [SearchPageRequest.previousSignal].
  factory withSignal(Future<(Iterable<T>, Object?)> Function(SearchPageRequest request) fetch) =>
      SearchPageFetcher._(fetch, reportsSignal: true);

  /// Fetches the page [request] describes, as its items and an optional end signal.
  Future<(Iterable<T>, Object?)> call(SearchPageRequest request) => _fetch(request);
}
