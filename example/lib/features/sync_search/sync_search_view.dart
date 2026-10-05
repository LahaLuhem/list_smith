import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'sync_search_view_model.dart';

/// `ListSmith.sync` with `SyncSearchPredicates.fields` over title and subtitle.
class const SyncSearchView({super.key}) extends StatelessWidget {
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
            child: Text('Type to filter. A query with no matches shows the no-results screen.'),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: PlatformSearchBar(hintText: 'Search items', onChanged: viewModel.onQueryChanged),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: viewModel.queryListenable,
              builder: (_, query, _) => ListSmith<DemoItem>.sync(
                items: viewModel.items,
                searchBy: SyncSearchPredicates.fields([
                  (item) => item.title,
                  (item) => item.subtitle,
                ]),
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
