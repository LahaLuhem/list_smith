import 'package:meta/meta.dart';

/// What a fetcher returns beside its items.
@internal
enum SignalKind() {
  /// Items only.
  none,

  /// A cursor the next page is asked for with.
  cursor,

  /// A `hasMore` flag.
  hasMore;

  /// Whether each page needs the signal the page before returned.
  bool get threadsSignal => this == cursor;

  /// Whether [lastPageSignal] ends the list.
  bool endsList(Object? lastPageSignal) => this == hasMore && lastPageSignal == false;
}
