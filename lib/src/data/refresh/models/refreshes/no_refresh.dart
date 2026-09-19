part of '../refresh.dart';

/// Pull-to-refresh off: no gesture, no indicator. Pass it to `.async`'s `refresh` to opt out.
final class NoRefresh extends Refresh {
  /// Creates it.
  const new();

  @override
  String toString() => 'NoRefresh()';
}
