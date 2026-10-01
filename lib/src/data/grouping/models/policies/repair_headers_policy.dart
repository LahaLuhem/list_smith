part of '../group_order_policy.dart';

/// Draws each group's header once, where the group first shows up. The default.
///
/// Out-of-order pages still assert in debug so you catch them early. In release the header just doesn't
/// repeat.
final class const RepairHeadersPolicy() extends GroupOrderPolicy {
  /// Creates it.
  this;

  @override
  String toString() => 'RepairHeadersPolicy()';
}
