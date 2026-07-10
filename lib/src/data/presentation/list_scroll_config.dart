import 'package:flutter/widgets.dart';

/// Groups the scroll and layout knobs for a list_smith list, so behavioural parameters don't share
/// the constructor signature with the scrollable's own configuration.
///
/// A curated subset of [ScrollView] / [BoxScrollView] options; every field is optional and defaults
/// to the framework's own default.
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

  /// Creates a scroll/layout configuration; every field defaults to the framework's own default.
  const ListScrollConfig({
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
