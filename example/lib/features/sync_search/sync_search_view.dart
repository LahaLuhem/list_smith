import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/widgets/bool_knob.dart';
import '/features/core/widgets/demo_item_tile.dart';
import '/features/core/widgets/demo_scaffold.dart';
import '/features/core/widgets/demo_search_bar.dart';
import 'sync_search_view_model.dart';

/// `ListSmith.sync` with `SyncSearchPredicates.fields` over title and subtitle, and `Grouping.by` on a
/// switch.
class const SyncSearchView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: SyncSearchViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Sync search',
      hint: 'Type to filter. A query with no matches shows the no-results screen.',
      controls: [
        ValueListenableBuilder(
          valueListenable: viewModel.shouldGroupListenable,
          builder: (_, shouldGroup, _) => BoolKnob(
            label: 'Group into sections',
            subtitle: 'The sections re-form over the matches',
            value: shouldGroup,
            onChanged: (value) => viewModel.onGroupToggled(value: value),
          ),
        ),
        DemoSearchBar(onChanged: viewModel.onQueryChanged),
      ],
      list: ValueListenableBuilder(
        valueListenable: viewModel.shouldGroupListenable,
        builder: (_, shouldGroup, _) => ValueListenableBuilder(
          valueListenable: viewModel.queryListenable,
          builder: (_, query, _) => ListSmith<DemoItem>.sync(
            items: viewModel.items,
            searchBy: SyncSearchPredicates.fields([(item) => item.title, (item) => item.subtitle]),
            query: query,
            grouping: shouldGroup
                ? Grouping.by(
                    groupBy: viewModel.categoryOf,
                    headerBuilder: (_, category) => _SectionHeader(label: category),
                  )
                : null,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, item, _) => DemoItemTile(item: item),
          ),
        ),
      ),
    ),
  );
}

class const _SectionHeader({required final String label}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(16, 16, 16, 4),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  );
}
