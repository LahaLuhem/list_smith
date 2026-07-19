part of '../empty_page_behaviour.dart';

/// Pages past empty pages to the first page that has items, or the true end.
///
/// When a page settles empty but [PaginationEndPolicy] reports another page, the list fetches the next
/// one itself instead of showing the empty surface, repeating until a page has items (it then renders
/// as usual) or the policy ends pagination (the empty surface shows then). The first-page loading
/// surface ([AsyncListSurfaces.firstPageLoadingBuilder]) is shown throughout, so the empty surface is
/// never flashed mid-advance.
///
/// Fits per-date or otherwise sparse sources, e.g. a calendar paged by day where the current day can
/// be empty while earlier days have entries. Without it the list sits on "today is empty" with no way
/// to scroll back to the days that aren't.
final class AdvanceToFirstNonEmpty extends EmptyPageBehaviour {
  /// The most pages to fetch while advancing before giving up and showing the empty surface, counted
  /// from the first page; `null` (the default) advances as far as [PaginationEndPolicy] allows.
  ///
  /// A safety cap for sources whose policy would otherwise scan a long (or unbounded) empty run, for
  /// example a signal policy over many empty dates: advancing stops once this many pages have been
  /// fetched and still hold nothing, and the empty surface shows. Pull-to-refresh re-scans from the
  /// first page.
  final int? maxPages;

  /// Creates an advance-past-empty behaviour, optionally capped at [maxPages] fetches.
  const AdvanceToFirstNonEmpty({this.maxPages})
    : assert(maxPages == null || maxPages > 0, 'maxPages must be positive when set.');

  @override
  bool shouldAdvance(EmptyPageContext context) {
    final cap = maxPages;

    return context.isEmpty && context.moreAvailable && (cap == null || context.pagesLoaded < cap);
  }

  @override
  String toString() => 'AdvanceToFirstNonEmpty(maxPages: $maxPages)';
}
