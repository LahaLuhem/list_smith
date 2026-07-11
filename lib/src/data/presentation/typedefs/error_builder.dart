import 'package:flutter/widgets.dart';

/// Builds an error surface for a page that failed to load.
///
/// Receives the `error` that occurred and an `onRetry` callback that re-attempts the failed load.
/// Carrying `onRetry` here (rather than a bare `WidgetBuilder`) lets a custom error surface offer
/// retry without reaching into list_smith's internals.
typedef ErrorBuilder = Widget Function(BuildContext context, Object error, VoidCallback onRetry);
