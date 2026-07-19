library;

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:pool/pool.dart';

import '../enums/reload_on_error.dart';
import 'reload_context.dart';

part 'reloads/reload_to_current_depth.dart';
part 'reloads/reset_to_first_page.dart';

/// What pull-to-refresh does to the pages already loaded.
///
/// A sealed, injected, defaulted seam carried on `PullToRefresh`. The default [ResetToFirstPage]
/// discards everything and reloads the first page (the underlying pager's behaviour);
/// [ReloadToCurrentDepth] re-fetches every loaded page so the user keeps their scroll depth across a
/// refresh.
///
/// Each variant carries its own logic in [run]; the async engine hands over a [ReloadContext] and calls
/// it, never inspecting the concrete type (see the CODESTYLE "behaviour lives in the sealed type" rule).
sealed class Reload {
  /// Const base constructor for the sealed hierarchy.
  const Reload();

  /// Performs the reload through [context]. The async engine calls this on each pull-to-refresh;
  /// consumers construct a variant but never call it, like building a `Widget` without calling `build`.
  @internal
  Future<void> run<T extends Object>(ReloadContext<T> context);
}
