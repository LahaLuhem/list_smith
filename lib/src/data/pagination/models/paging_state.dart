import 'package:meta/meta.dart';

import '../enums/paging_status.dart';
import 'loaded_page.dart';

/// What an async list holds: the pages loaded so far, and where its stream stands.
///
/// Compared by identity, so every write is a change a listener sees.
@immutable
final class const PagingState<T extends Object>({
  /// The pages loaded so far, in order, so page `i` sits at index `i`. Null until the 1st one lands.
  final List<LoadedPage<T>>? pages,

  /// What the last page fetch threw. Only [failed] sets it.
  final Exception? error,

  /// Whether the source may have more pages.
  final bool hasNextPage = true,

  /// Whether a page fetch is on its way.
  final bool isLoading = false,
}) {
  /// Creates it.
  this;

  /// The surface to show. Counts pages instead of flattening them, so it stays O(pages).
  PagingStatus get status {
    final pages = this.pages;
    if (pages == null) return error == null ? .loadingFirstPage : .firstPageError;
    if (pages.every((page) => page.items.isEmpty)) {
      return error == null ? .noItemsFound : .firstPageError;
    }
    if (!hasNextPage) return .completed;

    return error == null ? .ongoing : .subsequentPageError;
  }

  /// A fetch is on its way, so the last one's error goes.
  PagingState<T> loading() => PagingState(pages: pages, hasNextPage: hasNextPage, isLoading: true);

  /// The fetch on its way threw [error].
  PagingState<T> failed(Exception error) =>
      PagingState(pages: pages, error: error, hasNextPage: hasNextPage);

  /// Nothing on its way and no error, as a stream parked while searching should come back.
  PagingState<T> settled() => PagingState(pages: pages, hasNextPage: hasNextPage);

  /// A copy with the given fields replaced. The error only changes through [loading], [failed] and
  /// [settled].
  // Leaves error out on purpose, as the doc says.
  // ignore: avoid-incomplete-copy-with
  PagingState<T> copyWith({List<LoadedPage<T>>? pages, bool? hasNextPage, bool? isLoading}) =>
      PagingState(
        pages: pages ?? this.pages,
        error: error,
        hasNextPage: hasNextPage ?? this.hasNextPage,
        isLoading: isLoading ?? this.isLoading,
      );

  /// A copy keeping only the items [predicate] accepts, page by page.
  PagingState<T> filterItems(bool Function(T item) predicate) => copyWith(
    pages: pages
        ?.map(
          (page) => LoadedPage(
            items: page.items.where(predicate).toList(growable: false),
            readStamp: page.readStamp,
          ),
        )
        .toList(growable: false),
  );

  @override
  String toString() =>
      'PagingState('
      'pages: ${pages?.length}, '
      'error: $error, '
      'hasNextPage: $hasNextPage, '
      'isLoading: $isLoading'
      ')';
}
