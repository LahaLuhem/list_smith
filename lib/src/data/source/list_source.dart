import '../pagination/page_fetcher.dart';
import '../pagination/pagination_end_policy.dart';
import '../search/search_cache_policy.dart';
import '../search/search_page_fetcher.dart';
import '../search/sync_search_predicate.dart';

/// The internal, sealed representation of where a list_smith list gets its data.
///
/// Two cases: [AsyncSource] (paginated, optionally searchable) and [SyncSource] (in-memory search).
/// The widget's named constructors build one of these, so the dispatcher switches over a sealed type
/// instead of juggling nullable mode-fields (no parameter is ever silently inert). Never exposed:
/// consumers configure the list through the constructor parameters, not by constructing a source.
sealed class ListSource<T extends Object> {
  const ListSource();
}

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

  /// Decides how cached items carry across a normal ↔ search transition.
  final SearchCachePolicy searchCachePolicy;

  /// Bundles the async configuration built from the `.async` constructor.
  const AsyncSource({
    required this.fetchPage,
    required this.pageSize,
    required this.endPolicy,
    required this.searchCachePolicy,
    this.searchFetchPage,
  });

  /// Whether this source supports search, i.e. a [searchFetchPage] was provided.
  bool get supportsSearch => searchFetchPage != null;

  @override
  String toString() =>
      'AsyncSource(pageSize: $pageSize, endPolicy: $endPolicy, searchCachePolicy: $searchCachePolicy)';
}

/// A sync, in-memory source: the [items] to search over and the [searchBy] predicate that filters them.
///
/// A sync list is always about search (there is nothing to paginate or pull-to-refresh over an
/// in-memory list), so [searchBy] is required and never inert. [items] is kept as the raw iterable
/// the consumer passed and materialised once at the render boundary, following the house "accept a
/// general iterable, materialise deliberately" idiom; keeping the original reference lets the widget
/// tell an unchanged list from a new one and skip re-filtering.
final class SyncSource<T extends Object> extends ListSource<T> {
  /// The items to search over, as passed by the consumer (materialised once downstream).
  final Iterable<T> items;

  /// Decides whether an item matches the current query.
  final SyncSearchPredicate<T> searchBy;

  /// Bundles the in-memory search configuration built from the `.sync` constructor.
  const SyncSource({required this.items, required this.searchBy});

  @override
  String toString() => 'SyncSource()';
}
