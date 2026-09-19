part of '../group_order_policy.dart';

/// Draws each group's header once, where the group first shows up. The default.
///
/// Out-of-order pages still assert in debug so you catch them early. In release the header just doesn't
/// repeat.
final class RepairHeadersPolicy extends GroupOrderPolicy {
  /// Creates it.
  const new();

  @override
  String toString() => 'RepairHeadersPolicy()';
}
