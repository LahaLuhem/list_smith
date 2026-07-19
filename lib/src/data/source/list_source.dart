import '/src/data/pagination/models/empty_page_behaviour.dart';
import '/src/data/pagination/models/page_fetcher.dart';
import '/src/data/pagination/models/pagination_end_policy.dart';
import '/src/data/pagination/typedefs/item_id.dart';
import '/src/data/refresh/models/refresh.dart';
import '/src/data/search/models/search.dart';
import '/src/data/search/typedefs/sync_search_predicate.dart';

part 'sources/async_source.dart';
part 'sources/sync_source.dart';

/// The internal, sealed representation of where a list_smith list gets its data.
///
/// Two cases: [AsyncSource] (paginated, optionally searchable) and [SyncSource] (in-memory search).
/// The widget's named constructors build one of these, so the dispatcher switches over a sealed type
/// instead of juggling nullable mode-fields (no parameter is ever silently inert). Never exposed:
/// consumers configure the list through the constructor parameters, not by constructing a source.
sealed class ListSource<T extends Object> {
  const ListSource();
}
