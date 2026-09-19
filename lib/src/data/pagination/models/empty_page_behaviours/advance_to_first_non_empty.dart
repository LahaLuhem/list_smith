part of '../empty_page_behaviour.dart';

/// Pages past empty pages to the 1st one that has items, or to the true end.
///
/// Keeps fetching while [PaginationEndPolicy] reports another page, showing [AsyncListSurfaces.firstPageLoadingBuilder]
/// the whole way so the empty surface never flashes. For sparse sources: a calendar paged by day, where
/// today can be empty and earlier days aren't.
final class AdvanceToFirstNonEmpty extends EmptyPageBehaviour {
  /// Cap on pages fetched while advancing, counted from the 1st. Hit it and the empty surface shows,
  /// and a pull re-scans. `null` (the default) goes as far as [PaginationEndPolicy] allows.
  final int? maxPages;

  /// Creates it, optionally capped at [maxPages] fetches.
  const new({this.maxPages})
    : assert(maxPages == null || maxPages > 0, 'maxPages must be positive when set.');

  @override
  bool shouldAdvance(EmptyPageContext context) {
    final pageCap = maxPages;

    return context.isEmpty &&
        context.isMoreAvailable &&
        (pageCap == null || context.pagesLoaded < pageCap);
  }

  @override
  String toString() => 'AdvanceToFirstNonEmpty(maxPages: $maxPages)';
}
