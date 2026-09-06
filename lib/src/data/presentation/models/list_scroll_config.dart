import 'package:flutter/widgets.dart';

/// The scroll and layout knobs, gathered here so they don't crowd the behavioural parameters.
///
/// A curated subset of [ScrollView] / [BoxScrollView], each field defaulting to the framework's own
/// default.
@immutable
class ListScrollConfig {
  /// Padding around the list contents. Maps to [BoxScrollView.padding].
  final EdgeInsetsGeometry? padding;

  /// The scroll physics. Maps to [ScrollView.physics].
  final ScrollPhysics? physics;

  /// An externally-owned scroll controller. Maps to [ScrollView.controller].
  final ScrollController? controller;

  /// Whether the list scrolls in reverse. Maps to [ScrollView.reverse].
  final bool reverse;

  /// The axis along which the list scrolls. Maps to [ScrollView.scrollDirection].
  final Axis scrollDirection;

  /// The viewport cache extent, in logical pixels (the scrollable's cache extent).
  final double? cacheExtent;

  /// Creates a scroll/layout configuration. Each field defaults to the framework's own default.
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
