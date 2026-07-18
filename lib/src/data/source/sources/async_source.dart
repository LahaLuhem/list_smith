part of '../list_source.dart';

/// An async, paginated source: a [PageFetcher] and the [PaginationEndPolicy] that decides when its data runs out.
///
/// Bundles `pageSize` here (rather than on the widget) so it stays scoped to the async path:
/// the sync source carries no page size, so there is no inert field to explain away. Search is opt-in:
/// with a [searchFetchPage] the list gains a search mode governed by [searchCachePolicy]; without one
/// it is a pure pagination list and the search-related fields are inert.
final class AsyncSource<T extends Object> extends ListSource<T> {
  /// Fetches each page of items in normal (non-search) mode.
  final PageFetcher<T> fetchPage;

  /// Fetches each page of results in search mode; null when the list does not support search.
  final SearchPageFetcher<T>? searchFetchPage;

  /// The number of items requested per page, passed to [fetchPage] and [searchFetchPage].
  final int pageSize;

  /// Decides when pagination has reached the end (in either mode).
  final PaginationEndPolicy endPolicy;

  /// Whether the list has pull-to-refresh, and how its indicator is drawn.
  final Refresh refresh;

  /// Decides how cached items carry across a normal ↔ search transition.
  final SearchCachePolicy searchCachePolicy;

  /// Extracts a stable identity key per item to de-duplicate overlapping pages; null disables it.
  final ItemId<T>? itemId;

  /// Bundles the async configuration built from the `.async` constructor.
  const AsyncSource({
    required this.fetchPage,
    required this.pageSize,
    required this.endPolicy,
    required this.refresh,
    required this.searchCachePolicy,
    this.searchFetchPage,
    this.itemId,
  });

  /// Whether this source supports search, i.e. a [searchFetchPage] was provided.
  bool get supportsSearch => searchFetchPage != null;

  @override
  String toString() =>
      'AsyncSource(pageSize: $pageSize, endPolicy: $endPolicy, refresh: $refresh, '
      'searchCachePolicy: $searchCachePolicy)';
}
