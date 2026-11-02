part of '../group_order_policy.dart';

/// Gathers each group into one section, wherever its items arrive. The default.
@Deprecated(
  'Groups gather on their own now. Remove the orderPolicy argument, it goes at the next major.',
)
final class const RepairHeadersPolicy() extends GroupOrderPolicy {
  /// Creates it.
  @Deprecated(
    'Groups gather on their own now. Remove the orderPolicy argument, it goes at the next major.',
  )
  this;

  // Structurally covered by to_string_test.dart.
  // coverage:ignore-start
  @override
  String toString() => 'RepairHeadersPolicy()';
  // coverage:ignore-end
}
