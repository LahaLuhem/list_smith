part of '../refresh.dart';

/// Pull-to-refresh off: the list wires no refresh gesture and draws no refresh indicator.
///
/// Pass it to `.async`'s `refresh` to opt out; the default is [PullToRefresh].
final class NoRefresh extends Refresh {
  /// Creates the no-refresh case.
  const NoRefresh();

  @override
  String toString() => 'NoRefresh()';
}
