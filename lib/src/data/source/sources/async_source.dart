part of '../list_source.dart';

/// An async, paginated source: a [PageFetcher] plus the [PaginationEndPolicy] saying when the data runs
/// out.
///
/// Everything async-only lives here rather than on the widget, so the sync path carries no inert fields.
final class const AsyncSource<T extends Object>({
  /// Fetches each page in normal (non-search) mode.
  required final PageFetcher<T> fetchPage,

  /// How many items per page, passed to [fetchPage] and any search fetcher.
  required final int pageSize,

  /// Says when pagination has reached the end, in either mode.
  required final PaginationEndPolicy endPolicy,

  /// What to do when a page has no items but [endPolicy] reports more pages left.
  required final EmptyPageBehaviour onEmptyPage,

  /// Whether the list has pull-to-refresh, and how its indicator is drawn.
  required final Refresh refresh,

  /// Whether the list is searchable, and how: [NoSearch] for none, [AsyncSearch] for a search mode.
  required final Search<T> search,

  /// Tells items apart, for de-dup, edits and keeping each row with its item.
  required final ItemIdGetter<T> itemIdGetter,

  /// Whether the rows edits add and take animate.
  required final EditTransition editTransition,
}) extends ListSource<T> {
  /// Creates it.
  this;

  /// Whether [search] is an [AsyncSearch].
  bool get supportsSearch => search is AsyncSearch<T>;

  @override
  String toString() =>
      'AsyncSource('
      'pageSize: $pageSize, '
      'endPolicy: $endPolicy, '
      'onEmptyPage: $onEmptyPage, '
      'refresh: $refresh, '
      'search: $search, '
      'editTransition: $editTransition'
      ')';
}
