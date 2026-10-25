import 'package:meta/meta.dart';

/// The items taken out of their place, each by the stamp of the newest edit that took it out.
@internal
extension type const RemovalStamps(Map<Object, int> _stampsById) {
  /// The items taken out after a read stamped [readStamp]. Lazy, since most callers only count them.
  Iterable<Object> after(int readStamp) =>
      _stampsById.entries.where((entry) => entry.value > readStamp).map((entry) => entry.key);
}
