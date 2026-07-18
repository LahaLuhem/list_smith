/// @docImport '/src/data/refresh/models/refresh.dart';
/// @docImport '/src/widgets/list_smith.dart';
library;

import 'package:flutter/widgets.dart';

import '../typedefs/error_builder.dart';

/// Groups the overridable surfaces that only an async list has, so [ListSmith.async]'s behavioural
/// parameters aren't buried among a run of optional builders.
///
/// Every field is null by default, meaning "use list_smith's neutral widgets-layer default"; set one
/// to replace that surface. The surfaces gathered here exist only on the async path (page loading,
/// page errors, and the end-of-list footer). The pull-to-refresh indicator lives on [PullToRefresh],
/// alongside the toggle that enables it. Surfaces every list has, such as the empty-state builder,
/// stay directly on the constructor so they read the same whether the list was built with `.async` or
/// `.sync`.
///
/// Build one once and reuse it across every list to share a house style.
@immutable
class AsyncListSurfaces {
  /// Builds the first-page loading surface; null uses the neutral default.
  final WidgetBuilder? firstPageLoadingBuilder;

  /// Builds the loading footer shown while a further page loads; null uses the neutral default.
  final WidgetBuilder? newPageLoadingBuilder;

  /// Builds the first-page error surface, carrying the error and a retry callback; null uses the
  /// neutral default.
  final ErrorBuilder? firstPageErrorBuilder;

  /// Builds the new-page error footer, carrying the error and a retry callback; null uses the
  /// neutral default.
  final ErrorBuilder? newPageErrorBuilder;

  /// Builds the footer shown once every page has loaded; null uses the neutral default.
  final WidgetBuilder? noMoreItemsBuilder;

  /// Groups the async-only override surfaces; every field defaults to the neutral widgets-layer
  /// surface it replaces.
  const AsyncListSurfaces({
    this.firstPageLoadingBuilder,
    this.newPageLoadingBuilder,
    this.firstPageErrorBuilder,
    this.newPageErrorBuilder,
    this.noMoreItemsBuilder,
  });
}
