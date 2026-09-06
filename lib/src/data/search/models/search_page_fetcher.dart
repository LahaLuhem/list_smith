/// @docImport '/src/data/pagination/models/end_context.dart';
/// @docImport '/src/data/pagination/models/page_fetcher.dart';
library;

import 'search_page_request.dart';

/// Fetches one page of search results for an async list, given the [SearchPageRequest] describing it.
///
/// [PageFetcher] with the committed [SearchPageRequest.query] on the request, and the same two
/// builders: [SearchPageFetcher.new] for items only, [SearchPageFetcher.withSignal] to also return
/// an end signal. That signal is read by the end policy as [EndContext.lastPageSignal] and fed back
/// as [SearchPageRequest.previousSignal], so a cursor-driven search works the same way.
final class SearchPageFetcher<T extends Object> {
  final Future<(Iterable<T>, Object?)> Function(SearchPageRequest request) _fetch;

  /// Whether this fetcher was built with [SearchPageFetcher.withSignal].
  final bool reportsSignal;

  /// Wraps a function returning one page of results for the request's query and page.
  factory(Future<Iterable<T>> Function(SearchPageRequest request) fetch) =>
      SearchPageFetcher._((request) async => (await fetch(request), null), reportsSignal: false);

  const new _(this._fetch, {required this.reportsSignal});

  /// Wraps a function returning one page of results plus an end signal.
  factory withSignal(Future<(Iterable<T>, Object?)> Function(SearchPageRequest request) fetch) =>
      SearchPageFetcher._(fetch, reportsSignal: true);

  /// Fetches the page [request] describes, as its items and an optional end signal.
  Future<(Iterable<T>, Object?)> call(SearchPageRequest request) => _fetch(request);
}
