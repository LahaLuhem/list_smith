import 'package:flutter/widgets.dart';

/// Builds the surface for a page whose fetch threw an [Exception]. An [Error] is a bug, so it goes on to
/// the app instead.
///
/// `onRetry` re-attempts the load, so a custom error view can offer retry without a controller.
typedef ErrorBuilder = Widget Function(
  BuildContext context,
  Exception exception,
  VoidCallback onRetry,
);
