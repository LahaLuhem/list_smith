import 'package:flutter/widgets.dart';

/// Builds an error surface for a page that failed to load.
///
/// Gets the `error` plus an `onRetry` that re-attempts the load, so a custom error view can offer
/// retry without reaching for a controller.
typedef ErrorBuilder = Widget Function(BuildContext context, Object error, VoidCallback onRetry);
