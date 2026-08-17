/// @docImport 'end_context.dart';
/// @docImport 'pagination_end_policy.dart';
library;

import 'page_request.dart';

/// Fetches one page of items for an async list, given the [PageRequest] describing it.
///
/// The returned `Iterable` is materialised exactly once by list_smith at the boundary, so a lazy
/// `.map()` / `.where()` or a `Set` is fine without a trailing `.toList()`.
///
/// Build one with [PageFetcher.new] to return items only, leaving end-of-data to the injected
/// [PaginationEndPolicy] (by default, the first empty page). Build one with [PageFetcher.withSignal]
/// to also report an end signal the policy reads from [EndContext.lastPageSignal] (for example a
/// `hasMore` flag or a next-cursor); that signal reaches the next page as
/// [PageRequest.previousSignal], so a cursor source drives the next fetch from the cursor the previous
/// page returned. Pair a cursor source with [StopOnNullSignalPolicy] to end once the cursor runs out.
/// A misbehaving endpoint (for example a 404 past the last page) is the fetcher's job to catch and
/// turn into an empty page.
final class PageFetcher<T extends Object> {
  final Future<(Iterable<T>, Object?)> Function(PageRequest request) _fetch;

  /// Whether this fetcher reports an end signal, i.e. it was built with [PageFetcher.withSignal].
  final bool reportsSignal;

  /// Wraps a function returning one page of items; end-of-data is left to the [PaginationEndPolicy].
  factory(Future<Iterable<T>> Function(PageRequest request) fetch) =>
      PageFetcher._((request) async => (await fetch(request), null), reportsSignal: false);

  const new _(this._fetch, {required this.reportsSignal});

  /// Wraps a function returning one page of items with a new end signal (for example a `hasMore` flag
  /// or a next-cursor), surfaced to the end policy as [EndContext.lastPageSignal] and handed to the
  /// next fetch as [PageRequest.previousSignal].
  factory withSignal(Future<(Iterable<T>, Object?)> Function(PageRequest request) fetch) =>
      PageFetcher._(fetch, reportsSignal: true);

  /// Fetches the page [request] describes, as its items and an optional end signal.
  Future<(Iterable<T>, Object?)> call(PageRequest request) => _fetch(request);
}
