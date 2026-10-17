/// @docImport 'end_context.dart';
/// @docImport 'pagination_end_policy.dart';
library;

import 'package:meta/meta.dart';

import '../enums/signal_kind.dart';
import 'page_request.dart';

/// Fetches one page of items for an async list, from the [PageRequest] describing it.
///
/// The `Iterable` you return is turned into a list once at the boundary, so a lazy `.map()` / `.where()`
/// needs no trailing `.toList()`. A misbehaving endpoint (a 404 past the last page, say) is yours to
/// catch and hand back as an empty page.
///
/// [PageFetcher.new] returns items only and leaves the end to [PaginationEndPolicy].
/// [PageFetcher.withHasMore] also returns whether more follow, and ends the list on it.
/// [PageFetcher.withSignal] returns a signal too, which the policy reads as [EndContext.lastPageSignal]
/// and the next fetch gets as [PageRequest.previousSignal]. That's the cursor channel, so pair it with
/// [StopOnNullSignalPolicy].
final class const PageFetcher<T extends Object>._(
  final Future<(Iterable<T>, Object?)> Function(PageRequest request) _fetch, {

  /// What it returns beside its items.
  @internal required final SignalKind signalKind,
}) {
  /// Wraps a function returning one page of items, leaving the end to [PaginationEndPolicy].
  factory(Future<Iterable<T>> Function(PageRequest request) fetch) =>
      PageFetcher._((request) async => (await fetch(request), null), signalKind: .none);

  /// Wraps a function returning one page and whether more follow. `hasMore: false` ends the list.
  factory withHasMore(Future<(Iterable<T>, {bool hasMore})> Function(PageRequest request) fetch) =>
      PageFetcher._((request) async {
        final (items, :hasMore) = await fetch(request);

        return (items, hasMore);
      }, signalKind: .hasMore);

  /// Wraps a function returning one page and a signal, like the next cursor.
  factory withSignal(Future<(Iterable<T>, Object?)> Function(PageRequest request) fetch) =>
      PageFetcher._(fetch, signalKind: .cursor);

  /// Fetches the page [request] describes, as its items and an optional end signal.
  Future<(Iterable<T>, Object?)> call(PageRequest request) => _fetch(request);
}
