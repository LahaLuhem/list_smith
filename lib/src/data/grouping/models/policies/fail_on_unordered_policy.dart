part of '../group_order_policy.dart';

/// Throws a [StateError] when a group key comes back after its section ended, in release too.
@Deprecated(
  "Out-of-order pages gather into their sections now, so there's nothing left to fail on. Remove "
  'the orderPolicy argument, it goes at the next major.',
)
final class const FailOnUnorderedPolicy() extends GroupOrderPolicy {
  /// Creates it.
  @Deprecated(
    "Out-of-order pages gather into their sections now, so there's nothing left to fail on. Remove "
    'the orderPolicy argument, it goes at the next major.',
  )
  this;

  @override
  String toString() => 'FailOnUnorderedPolicy()';
}
