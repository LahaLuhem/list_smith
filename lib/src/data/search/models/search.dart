/// @docImport '/src/widgets/list_smith.dart';
library;

import 'search_cache_policy.dart';
import 'search_page_fetcher.dart';

part 'searches/async_search.dart';
part 'searches/no_search.dart';

/// Whether an async list is searchable, and how search behaves.
///
/// A sealed, injected, defaulted seam, like the pagination end and search cache policies: the default
/// is [NoSearch] (a plain paginated list), and search is opted into with [AsyncSearch], which carries
/// the search fetcher and its cache policy together. Applies to [ListSmith.async] only; a `.sync` list
/// is always a search over in-memory items, so it takes its predicate directly (see [ListSmith.sync]).
/// Bundling the fetcher with the cache policy means neither can be set on a non-searching list, so a
/// cache policy is never left inert.
sealed class Search<T extends Object> {
  /// Const base constructor for the sealed hierarchy.
  const Search();
}
