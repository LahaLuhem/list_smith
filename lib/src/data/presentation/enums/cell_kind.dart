import 'package:meta/meta.dart';

/// What a child of the rows sliver shows.
@internal
enum CellKind() {
  /// A group's header.
  header,

  /// An item's row.
  item,

  /// The separator after an item.
  separator,

  /// The cell after the rows.
  footer,
}
