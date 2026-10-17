/// @docImport '/src/data/pagination/models/page_fetcher.dart';
library;

import 'package:meta/meta.dart';

import '/src/data/pagination/enums/signal_kind.dart';
import 'search_page_request.dart';

/// Fetches one page of search results, from the [SearchPageRequest] describing it.
///
/// [PageFetcher] with the committed query on the request, and the same 3 builders.
final class const SearchPageFetcher<T extends Object>._(
  final Future<(Iterable<T>, Object?)> Function(SearchPageRequest request) _fetch, {

  /// What it returns beside its items.
  @internal required final SignalKind signalKind,
}) {
  /// Wraps a function returning one page of results for the request's query and page.
  factory(Future<Iterable<T>> Function(SearchPageRequest request) fetch) =>
      SearchPageFetcher._((request) async => (await fetch(request), null), signalKind: .none);

  /// Wraps a function returning one page of results and whether more follow. `hasMore: false` ends
  /// the results.
  factory withHasMore(
    Future<(Iterable<T>, {bool hasMore})> Function(SearchPageRequest request) fetch,
  ) => SearchPageFetcher._((request) async {
    final (items, :hasMore) = await fetch(request);

    return (items, hasMore);
  }, signalKind: .hasMore);

  /// Wraps a function returning one page of results and a signal, like the next cursor.
  factory withSignal(Future<(Iterable<T>, Object?)> Function(SearchPageRequest request) fetch) =>
      SearchPageFetcher._(fetch, signalKind: .cursor);

  /// Fetches the page [request] describes, as its items and an optional end signal.
  Future<(Iterable<T>, Object?)> call(SearchPageRequest request) => _fetch(request);
}
