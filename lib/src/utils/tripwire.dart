import 'package:meta/meta.dart';

/// A one-way flag: starts untripped, can be tripped once, never reset.
@internal
final class Tripwire() {
  var _hasTripped = false;

  /// Creates it.
  this;

  /// Whether [trip] ran.
  bool get hasTripped => _hasTripped;

  /// Returns true only for the call that flipped it, like [Set.add].
  bool trip() {
    if (_hasTripped) return false;

    return _hasTripped = true;
  }
}
