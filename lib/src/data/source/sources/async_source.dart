part of '../list_source.dart';

/// An async, paginated source: a [PageFetcher] and the [PaginationEndPolicy] that decides when its data runs out.
///
/// Bundles `pageSize` here (rather than on the widget) so it stays scoped to the async path: the sync
/// source carries no page size, so there is no inert field to explain away. Search is opt-in through
/// the [search] seam: an [AsyncSearch] gives the list a search mode with its own fetcher and cache
/// policy, while the default [NoSearch] is a pure pagination list with no search config left inert.
final class AsyncSource<T extends Object> extends ListSource<T> {
  /// Fetches each page of items in normal (non-search) mode.
  final PageFetcher<T> fetchPage;

  /// The number of items requested per page, passed to [fetchPage] and any search fetcher.
  final int pageSize;

  /// Decides when pagination has reached the end (in either mode).
  final PaginationEndPolicy endPolicy;

  /// Whether the list has pull-to-refresh, and how its indicator is drawn.
  final Refresh refresh;

  /// Whether the list is searchable, and how: [NoSearch] for none, [AsyncSearch] for a search mode.
  final Search<T> search;

  /// Extracts a stable identity key per item to de-duplicate overlapping pages; null disables it.
  final ItemId<T>? itemId;

  /// Bundles the async configuration built from the `.async` constructor.
  const AsyncSource({
    required this.fetchPage,
    required this.pageSize,
    required this.endPolicy,
    required this.refresh,
    required this.search,
    this.itemId,
  });

  /// Whether this source supports search, i.e. [search] is an [AsyncSearch].
  bool get supportsSearch => search is AsyncSearch<T>;

  @override
  String toString() =>
      'AsyncSource(pageSize: $pageSize, endPolicy: $endPolicy, refresh: $refresh, search: $search)';
}
