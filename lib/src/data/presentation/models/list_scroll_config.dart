import 'package:flutter/widgets.dart';

/// The scroll and layout knobs, kept together so they don't crowd the behaviour parameters.
///
/// A subset of [ScrollView] / [BoxScrollView], each field keeping the framework's own default.
@immutable
class ListScrollConfig {
  /// Maps to [BoxScrollView.padding].
  final EdgeInsetsGeometry? padding;

  /// Maps to [ScrollView.physics].
  final ScrollPhysics? physics;

  /// Maps to [ScrollView.controller], for a scroll controller you own.
  final ScrollController? controller;

  /// Maps to [ScrollView.reverse].
  final bool reverse;

  /// Maps to [ScrollView.scrollDirection].
  final Axis scrollDirection;

  /// The viewport cache extent, in logical pixels.
  final double? cacheExtent;

  /// Creates it.
  const new({
    this.padding,
    this.physics,
    this.controller,
    this.reverse = false,
    this.scrollDirection = .vertical,
    this.cacheExtent,
  });

  @override
  String toString() =>
      'ListScrollConfig('
      'padding: $padding, '
      'physics: $physics, '
      'reverse: $reverse, '
      'scrollDirection: $scrollDirection, '
      'cacheExtent: $cacheExtent'
      ')';
}
