import 'package:flutter/foundation.dart' show immutable;

/// One row in the demo dataset. Deliberately tiny: a stable [id] plus two text fields the item
/// builders render. [matches] is a single title-based rule used by the async search fetch and the
/// grouping demo; the sync search demo instead uses `SyncSearchPredicates.fields` over both fields.
@immutable
class DemoItem {
  final int id;
  final String title;
  final String subtitle;

  const DemoItem({required this.id, required this.title, required this.subtitle});

  /// Whether this item matches [query] (case-insensitive substring of [title]). Used by the async
  /// search fetch and the grouping demo. The sync search demo instead builds its predicate with
  /// `SyncSearchPredicates.fields` over title and subtitle.
  bool matches(String query) => title.toLowerCase().contains(query.toLowerCase());

  @override
  String toString() => 'DemoItem(id: $id, title: $title)';
}
