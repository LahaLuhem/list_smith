import 'package:flutter/foundation.dart' show immutable;

/// One row in the demo dataset. Deliberately tiny: a stable [id] plus two text fields the item
/// builders render, with [matches] giving the search demos a single title-based match rule.
@immutable
class DemoItem {
  final int id;
  final String title;
  final String subtitle;

  const DemoItem({required this.id, required this.title, required this.subtitle});

  /// Whether this item matches [query] (case-insensitive substring of [title]). Shared by the sync
  /// search predicate and the async search fetch, so both demos filter identically.
  bool matches(String query) => title.toLowerCase().contains(query.toLowerCase());

  @override
  String toString() => 'DemoItem(id: $id, title: $title)';
}
