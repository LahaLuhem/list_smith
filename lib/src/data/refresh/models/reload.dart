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
/// [ResetToFirstPage] (the default) throws everything away and reloads page one. [ReloadToCurrentDepth]
/// re-fetches every loaded page, so scroll depth survives.
sealed class Reload {
  /// Const base constructor.
  const new();

  /// Does the reload through [context]. The engine calls it, you don't, same as `Widget.build`.
  @internal
  Future<void> run<T extends Object>(ReloadContext<T> context);
}
