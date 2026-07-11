import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'async_search_view_model.dart';

/// Async two-view search with `ListSmith.async`: a paginated feed that switches to paginated search
/// results and back, with a live `SearchCachePolicy` toggle (Keep vs the default Replace).
class AsyncSearchView extends StatelessWidget {
  const AsyncSearchView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: AsyncSearchViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Async search',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Padding(
            padding: .all(16),
            child: DemoIntro(
              title: 'ListSmith.async + search',
              description:
                  'Paginates the feed; a query switches to paginated search results and back. Turn on '
                  '"Keep list across search", scroll the feed, search, then clear to land back where '
                  'you were; with it off (the default), clearing reloads from the top.',
            ),
          ),
          _KeepCacheToggle(
            keepCache: viewModel.keepCacheListenable,
            onChanged: (value) => viewModel.onKeepCacheToggled(value: value),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: PlatformSearchBar(hintText: 'Search items', onChanged: viewModel.onQueryChanged),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: viewModel.keepCacheListenable,
              builder: (_, keepCache, _) => ValueListenableBuilder(
                valueListenable: viewModel.queryListenable,
                builder: (_, query, _) => ListSmith.async(
                  fetchPage: viewModel.fetchPage,
                  searchFetchPage: viewModel.searchFetchPage,
                  query: query,
                  searchCachePolicy: keepCache
                      ? const KeepCachePolicy()
                      : const ReplaceCachePolicy(),
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, item, _) =>
                      PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A labelled switch toggling whether the normal feed is kept across a search.
class _KeepCacheToggle extends StatelessWidget {
  final ValueListenable<bool> keepCache;
  final ValueChanged<bool> onChanged;

  const _KeepCacheToggle({required this.keepCache, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(horizontal: 16),
    child: Row(
      children: [
        const Expanded(child: Text('Keep list across search')),
        ValueListenableBuilder(
          valueListenable: keepCache,
          builder: (_, value, _) => PlatformSwitch(value: value, onChanged: onChanged),
        ),
      ],
    ),
  );
}
