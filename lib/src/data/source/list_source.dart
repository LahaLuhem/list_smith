import '/src/data/pagination/models/empty_page_behaviour.dart';
import '/src/data/pagination/models/page_fetcher.dart';
import '/src/data/pagination/models/pagination_end_policy.dart';
import '/src/data/pagination/typedefs/item_id.dart';
import '/src/data/refresh/models/refresh.dart';
import '/src/data/search/models/search.dart';
import '/src/data/search/typedefs/sync_search_predicate.dart';

part 'sources/async_source.dart';
part 'sources/sync_source.dart';

/// Where a list_smith list gets its data. Internal, never exposed.
///
/// [AsyncSource] (paginated, optionally searchable) or [SyncSource] (in-memory search). The named
/// constructors build one, so the dispatcher switches a sealed type instead of juggling nullable
/// mode-fields, and no parameter is ever silently inert.
sealed class ListSource<T extends Object> {
  const new();
}
