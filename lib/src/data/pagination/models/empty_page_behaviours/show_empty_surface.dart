part of '../empty_page_behaviour.dart';

/// Shows the empty surface as soon as a page settles with no items, fetching no further. The default.
///
/// In search mode that's the no-results builder instead. Under an end policy that continues past
/// empty pages this stalls the list on the first empty one, so pass [AdvanceToFirstNonEmpty] to page
/// through.
final class ShowEmptySurface extends EmptyPageBehaviour {
  /// Creates the show-empty-surface behaviour (the default).
  const new();

  @override
  bool shouldAdvance(EmptyPageContext context) => false;

  @override
  String toString() => 'ShowEmptySurface()';
}
