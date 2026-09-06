/// @docImport '/src/data/refresh/models/refresh.dart';
library;

import 'package:flutter/widgets.dart';

import '../typedefs/error_builder.dart';

/// The overridable surfaces only an async list has: page loading, page errors, the end-of-list
/// footer.
///
/// Every unset field keeps list_smith's own neutral surface. Build one and reuse it across lists for
/// a house style. The pull indicator isn't here, it sits on [PullToRefresh] next to the toggle that
/// turns it on, and surfaces every list has (the empty state) stay on the constructor.
@immutable
class AsyncListSurfaces {
  /// Builds the first-page loading surface. Null uses the neutral default.
  final WidgetBuilder? firstPageLoadingBuilder;

  /// Builds the loading footer shown while a further page loads. Null uses the neutral default.
  final WidgetBuilder? newPageLoadingBuilder;

  /// Builds the first-page error surface, carrying the error and a retry callback. Null uses the
  /// neutral default.
  final ErrorBuilder? firstPageErrorBuilder;

  /// Builds the new-page error footer, carrying the error and a retry callback. Null uses the
  /// neutral default.
  final ErrorBuilder? newPageErrorBuilder;

  /// Builds the footer shown once every page has loaded. Null uses the neutral default.
  final WidgetBuilder? noMoreItemsBuilder;

  /// Creates a surface set. Every unset field keeps list_smith's neutral default.
  const new({
    this.firstPageLoadingBuilder,
    this.newPageLoadingBuilder,
    this.firstPageErrorBuilder,
    this.newPageErrorBuilder,
    this.noMoreItemsBuilder,
  });
}
