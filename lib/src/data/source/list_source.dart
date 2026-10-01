import '/src/data/edits/models/edit_transition.dart';
import '/src/data/pagination/models/empty_page_behaviour.dart';
import '/src/data/pagination/models/page_fetcher.dart';
import '/src/data/pagination/models/pagination_end_policy.dart';
import '/src/data/pagination/typedefs/item_id_getter.dart';
import '/src/data/refresh/models/refresh.dart';
import '/src/data/search/models/search.dart';
import '/src/data/search/typedefs/sync_search_predicate.dart';

part 'sources/async_source.dart';
part 'sources/sync_source.dart';

/// Where a list gets its data. Internal, never exposed.
///
/// [AsyncSource] (paginated, optionally searchable) or [SyncSource] (in-memory search). Each named constructor
/// builds one, so no parameter is ever silently inert on the wrong mode.
sealed class const ListSource<T extends Object>();
