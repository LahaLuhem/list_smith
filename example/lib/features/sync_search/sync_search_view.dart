import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'sync_search_view_model.dart';

/// Client-side search over an in-memory list with `ListSmith.sync`: instant filtering, no paging.
/// Clear the query to see every item; search for something absent to see the no-results surface.
class SyncSearchView extends StatelessWidget {
  const SyncSearchView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: SyncSearchViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Sync search',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Padding(
            padding: .all(16),
            child: DemoIntro(
              title: 'ListSmith.sync',
              description:
                  'Filters a fixed in-memory list as you type. Clearing the query shows every item; '
                  'a query that matches nothing shows the no-results surface.',
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: PlatformSearchBar(hintText: 'Search items', onChanged: viewModel.onQueryChanged),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: viewModel.queryListenable,
              builder: (_, query, _) => ListSmith.sync(
                items: viewModel.items,
                searchBy: (item, query) => item.matches(query),
                query: query,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, item, _) =>
                    PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle)),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
