import 'package:meta/meta.dart';

import '/src/data/edits/edits.dart';
import '/src/data/pagination/pagination.dart';
import '/src/data/refresh/refresh.dart';
import '/src/data/search/search.dart';

part 'sources/async_source.dart';
part 'sources/sync_source.dart';

/// Where a list gets its data. Internal, never exposed.
///
/// [AsyncSource] (paginated, optionally searchable) or [SyncSource] (in-memory search). Each named constructor
/// builds one, so no parameter is ever silently inert on the wrong mode.
@internal
sealed class const ListSource<T extends Object>() {
  /// Const base constructor.
  this;
}
