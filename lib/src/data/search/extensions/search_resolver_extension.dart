import 'package:meta/meta.dart';

import '../enums/cache_action.dart';
import '../models/search.dart';
import 'search_cache_policy_resolver_extension.dart';

/// Maps a [Search] and a mode change to the [CacheAction] the list runs.
@internal
extension SearchResolverExtension on Search<Object> {
  /// The action for a move from [wasSearching] to [isSearching]. Search taken away lands like a cleared
  /// query: on the kept feed if there is one.
  CacheAction cacheActionFor({required bool wasSearching, required bool isSearching}) =>
      switch (this) {
        AsyncSearch(:final cachePolicy) => cachePolicy.actionFor(
          wasSearching: wasSearching,
          isSearching: isSearching,
        ),
        NoSearch() => .restoreNormal,
      };
}
