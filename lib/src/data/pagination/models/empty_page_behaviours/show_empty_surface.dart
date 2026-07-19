part of '../empty_page_behaviour.dart';

/// Shows the empty surface as soon as a page settles with no items, fetching no further.
///
/// The default, and the underlying pager's own behaviour: an empty page renders the empty builder (or
/// the no-results builder in search mode) straight away. Under an end policy that continues past empty
/// pages this stops the list on the first empty page; pass [AdvanceToFirstNonEmpty] to page through to
/// the first page with items instead.
final class ShowEmptySurface extends EmptyPageBehaviour {
  /// Creates the show-empty-surface behaviour (the default).
  const ShowEmptySurface();

  @override
  bool shouldAdvance(EmptyPageContext context) => false;

  @override
  String toString() => 'ShowEmptySurface()';
}
