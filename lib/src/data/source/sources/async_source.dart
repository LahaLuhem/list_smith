part of '../list_source.dart';

/// An async, paginated source: a [PageFetcher] plus the [PaginationEndPolicy] saying when the data runs
/// out.
///
/// Everything async-only lives here rather than on the widget, so the sync path carries no inert fields.
final class AsyncSource<T extends Object> extends ListSource<T> {
  /// Fetches each page in normal (non-search) mode.
  final PageFetcher<T> fetchPage;

  /// How many items per page, passed to [fetchPage] and any search fetcher.
  final int pageSize;

  /// Says when pagination has reached the end, in either mode.
  final PaginationEndPolicy endPolicy;

  /// What to do when a page has no items but [endPolicy] reports more pages left.
  final EmptyPageBehaviour onEmptyPage;

  /// Whether the list has pull-to-refresh, and how its indicator is drawn.
  final Refresh refresh;

  /// Whether the list is searchable, and how: [NoSearch] for none, [AsyncSearch] for a search mode.
  final Search<T> search;

  /// Pulls a stable identity key per item to de-duplicate overlapping pages. Null disables it.
  final ItemId<T>? itemId;

  /// Creates it.
  const new({
    required this.fetchPage,
    required this.pageSize,
    required this.endPolicy,
    required this.onEmptyPage,
    required this.refresh,
    required this.search,
    this.itemId,
  });

  /// Whether [search] is an [AsyncSearch].
  bool get supportsSearch => search is AsyncSearch<T>;

  @override
  String toString() =>
      'AsyncSource(pageSize: $pageSize, endPolicy: $endPolicy, onEmptyPage: $onEmptyPage, '
      'refresh: $refresh, search: $search)';
}
