part of '../empty_page_behaviour.dart';

/// Pages past empty pages to the first page that has items, or the true end.
///
/// Keeps fetching while [PaginationEndPolicy] reports another page, showing
/// [AsyncListSurfaces.firstPageLoadingBuilder] the whole way so the empty surface never flashes.
/// For sparse sources: a calendar paged by day, where today can be empty and earlier days aren't.
final class AdvanceToFirstNonEmpty extends EmptyPageBehaviour {
  /// Cap on pages fetched while advancing, counted from the first. Hit it and the empty surface
  /// shows, and a pull re-scans. `null` (the default) advances as far as [PaginationEndPolicy] allows.
  final int? maxPages;

  /// Creates an advance-past-empty behaviour, optionally capped at [maxPages] fetches.
  const new({this.maxPages})
    : assert(maxPages == null || maxPages > 0, 'maxPages must be positive when set.');

  @override
  bool shouldAdvance(EmptyPageContext context) {
    final cap = maxPages;

    return context.isEmpty && context.moreAvailable && (cap == null || context.pagesLoaded < cap);
  }

  @override
  String toString() => 'AdvanceToFirstNonEmpty(maxPages: $maxPages)';
}
