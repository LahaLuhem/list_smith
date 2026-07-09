import '../pagination/page_fetcher.dart';
import '../pagination/pagination_end_policy.dart';

/// The internal, sealed representation of where a list_smith list gets its data.
///
/// V1 ships only [AsyncSource]; a sync source arrives with search. The widget's named constructors
/// build one of these, so the shell switches over a sealed type instead of juggling nullable mode-fields
/// (no parameter is ever silently inert). Never exposed: consumers configure the list through the
/// constructor parameters, not by constructing a source.
sealed class ListSource<T extends Object> {
  const ListSource();
}

/// An async, paginated source: a [PageFetcher] and the [PaginationEndPolicy] that decides when its data runs out.
///
/// Bundles `pageSize` here (rather than on the widget) so it stays scoped to the async path:
/// a future sync source carries no page size, so there is no inert field to explain away.
final class AsyncSource<T extends Object> extends ListSource<T> {
  /// Fetches each page of items.
  final PageFetcher<T> fetchPage;

  /// The number of items requested per page, passed to [fetchPage].
  final int pageSize;

  /// Decides when pagination has reached the end.
  final PaginationEndPolicy endPolicy;

  /// Bundles the async pagination configuration built from the `.async` constructor.
  const AsyncSource({required this.fetchPage, required this.pageSize, required this.endPolicy});

  @override
  String toString() => 'AsyncSource(pageSize: $pageSize, endPolicy: $endPolicy)';
}
