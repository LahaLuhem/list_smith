import 'package:flutter/foundation.dart' show immutable;

/// One row in the demo dataset: a stable [id] plus 2 text fields the item builders render.
@immutable
class DemoItem {
  final int id;
  final String title;
  final String subtitle;

  const new({required this.id, required this.title, required this.subtitle});

  /// Whether [title] contains [query], case-insensitively.
  bool matches(String query) => title.toLowerCase().contains(query.toLowerCase());

  @override
  String toString() => 'DemoItem(id: $id, title: $title)';
}
