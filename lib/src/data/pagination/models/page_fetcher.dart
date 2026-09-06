/// @docImport 'end_context.dart';
/// @docImport 'pagination_end_policy.dart';
library;

import 'page_request.dart';

/// Fetches one page of items for an async list, given the [PageRequest] describing it.
///
/// The returned `Iterable` is materialised once at the boundary, so a lazy `.map()` / `.where()`
/// needs no trailing `.toList()`. A misbehaving endpoint (a 404 past the last page, say) is yours to
/// catch and return as an empty page.
///
/// [PageFetcher.new] returns items only and leaves the end to [PaginationEndPolicy].
/// [PageFetcher.withSignal] also returns a signal, read by the policy as
/// [EndContext.lastPageSignal] and by the next fetch as [PageRequest.previousSignal]. That is the
/// cursor channel, so pair it with [StopOnNullSignalPolicy].
final class PageFetcher<T extends Object> {
  final Future<(Iterable<T>, Object?)> Function(PageRequest request) _fetch;

  /// Whether this fetcher was built with [PageFetcher.withSignal].
  final bool reportsSignal;

  /// Wraps a function returning one page of items, leaving the end to [PaginationEndPolicy].
  factory(Future<Iterable<T>> Function(PageRequest request) fetch) =>
      PageFetcher._((request) async => (await fetch(request), null), reportsSignal: false);

  const new _(this._fetch, {required this.reportsSignal});

  /// Wraps a function returning one page plus an end signal: a `hasMore` flag, a next cursor.
  factory withSignal(Future<(Iterable<T>, Object?)> Function(PageRequest request) fetch) =>
      PageFetcher._(fetch, reportsSignal: true);

  /// Fetches the page [request] describes, as its items and an optional end signal.
  Future<(Iterable<T>, Object?)> call(PageRequest request) => _fetch(request);
}
