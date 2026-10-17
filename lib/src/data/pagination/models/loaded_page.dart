import 'package:meta/meta.dart';

/// One loaded page: the items the server sent, and the edit counter when its fetch went out, so an
/// edit can tell pages read before it from pages read after.
///
/// A class rather than a record, since a record costs the de-dup pass about half again.
@immutable
@internal
final class const LoadedPage<T extends Object>({
  /// The items, as the server sent them.
  required final List<T> items,

  /// The edit counter when this page's fetch went out.
  required final int readStamp,

  /// The signal its fetch went out with, sent again when it's read again.
  final Object? previousSignal,
}) {
  /// Creates it.
  this;
}
