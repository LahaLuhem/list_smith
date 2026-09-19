/// @docImport '/src/data/refresh/models/refresh.dart';
library;

import 'package:flutter/widgets.dart';

import '../typedefs/error_builder.dart';

/// The overridable surfaces only an async list has: page loading, page errors, the end-of-list footer.
///
/// Anything you leave unset keeps list_smith's neutral surface. Build one and reuse it across lists
/// for a house style. The pull indicator lives on [PullToRefresh] instead, and the empty state sits
/// on the constructor, since every list has one.
@immutable
class AsyncListSurfaces {
  /// Builds the first-page loading surface.
  final WidgetBuilder? firstPageLoadingBuilder;

  /// Builds the loading footer shown while a further page loads.
  final WidgetBuilder? newPageLoadingBuilder;

  /// Builds the first-page error surface, with the error and a retry callback.
  final ErrorBuilder? firstPageErrorBuilder;

  /// Builds the new-page error footer, with the error and a retry callback.
  final ErrorBuilder? newPageErrorBuilder;

  /// Builds the footer shown once every page has loaded.
  final WidgetBuilder? noMoreItemsBuilder;

  /// Creates it. Every unset field keeps list_smith's neutral default.
  const new({
    this.firstPageLoadingBuilder,
    this.newPageLoadingBuilder,
    this.firstPageErrorBuilder,
    this.newPageErrorBuilder,
    this.noMoreItemsBuilder,
  });
}
