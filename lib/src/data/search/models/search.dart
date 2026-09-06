/// @docImport '/src/widgets/list_smith.dart';
library;

import 'search_cache_policy.dart';
import 'search_page_fetcher.dart';

part 'searches/async_search.dart';
part 'searches/no_search.dart';

/// Whether an async list is searchable, and how search behaves.
///
/// [NoSearch] (the default) is a plain paginated list. [AsyncSearch] turns search on and carries the
/// fetcher and cache policy together, so neither can be set on a list that doesn't search.
/// [ListSmith.async] only: a [ListSmith.sync] list is search by definition and takes its predicate
/// directly.
sealed class Search<T extends Object> {
  /// Const base constructor.
  const new();
}
