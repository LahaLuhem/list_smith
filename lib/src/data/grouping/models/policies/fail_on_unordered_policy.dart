part of '../group_order_policy.dart';

/// Throws a [StateError] when pages arrive out of group order, in release too.
///
/// Pick it when a wrong-looking list is worse than a crash. Costs an order check every build, which
/// [RepairHeadersPolicy] only pays in debug.
final class FailOnUnorderedPolicy extends GroupOrderPolicy {
  /// Creates a policy that throws on out-of-order pages.
  const new();

  @override
  String toString() => 'FailOnUnorderedPolicy()';
}
