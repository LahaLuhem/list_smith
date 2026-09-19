import 'package:flutter/widgets.dart';

/// Builds the surface for a page that failed to load.
///
/// `onRetry` re-attempts the load, so a custom error view can offer retry without a controller.
typedef ErrorBuilder = Widget Function(BuildContext context, Object error, VoidCallback onRetry);
