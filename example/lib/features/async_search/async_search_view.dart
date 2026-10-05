import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/bool_knob.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'async_search_view_model.dart';

/// `ListSmith.async` plus `AsyncSearch`, switching `SearchCachePolicy` between Keep and Replace.
class const AsyncSearchView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: AsyncSearchViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Async search',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .fromLTRB(16, 16, 16, 8),
            child: ValueListenableBuilder(
              valueListenable: viewModel.shouldKeepCacheListenable,
              builder: (_, shouldKeepCache, _) => BoolKnob(
                label: 'Keep list across search',
                subtitle: 'Clearing a search lands back where you were',
                value: shouldKeepCache,
                onChanged: (value) => viewModel.onKeepCacheToggled(value: value),
              ),
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: PlatformSearchBar(hintText: 'Search items', onChanged: viewModel.onQueryChanged),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: viewModel.shouldKeepCacheListenable,
              builder: (_, shouldKeepCache, _) => ValueListenableBuilder(
                valueListenable: viewModel.queryListenable,
                builder: (_, query, _) => ListSmith.async(
                  fetchPage: PageFetcher(viewModel.fetchPage),
                  itemIdGetter: (item) => item.id,
                  search: AsyncSearch(
                    fetchPage: SearchPageFetcher(viewModel.searchFetchPage),
                    cachePolicy: shouldKeepCache
                        ? const KeepCachePolicy()
                        : const ReplaceCachePolicy(),
                  ),
                  query: query,
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
