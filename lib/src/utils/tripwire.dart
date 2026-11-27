import 'package:meta/meta.dart';

/// A one-way flag: once tripped, it stays tripped.
@internal
final class Tripwire() {
  var _hasTripped = false;

  /// Creates it.
  this;

  /// Whether [trip] ran.
  bool get hasTripped => _hasTripped;

  /// True only for the call that tripped it, like [Set.add].
  bool trip() {
    if (_hasTripped) return false;

    return _hasTripped = true;
  }
}
