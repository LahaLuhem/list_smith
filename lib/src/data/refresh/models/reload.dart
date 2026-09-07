library;

import 'dart:async';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:pool/pool.dart';

import '../enums/reload_on_error.dart';
import 'reload_context.dart';

part 'reloads/reload_to_current_depth.dart';
part 'reloads/reset_to_first_page.dart';

/// What pull-to-refresh does to the pages already loaded.
///
/// Carried on `PullToRefresh`. [ResetToFirstPage] (the default) discards everything and reloads page
/// one. [ReloadToCurrentDepth] re-fetches every loaded page so scroll depth survives.
///
/// Each variant does its own work in [run], which the engine calls with a [ReloadContext] without
/// ever inspecting the concrete type.
sealed class Reload {
  /// Const base constructor.
  const new();

  /// Performs the reload through [context]. The engine calls this, never the consumer, the same way
  /// nobody calls `Widget.build` by hand.
  @internal
  Future<void> run<T extends Object>(ReloadContext<T> context);
}
