import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_item_tile.dart';
import '/features/core/widgets/demo_scaffold.dart';
import '/features/core/widgets/demo_search_bar.dart';
import 'grouping_view_model.dart';

/// `ListSmith.sync` plus `Grouping.by`. The fixture cycles 3 categories per row, so the raw list is
/// interleaved and sync bucketing has something to do.
class const GroupingView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: GroupingViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Grouping',
      hint: 'Search, and the sections re-form over the matches.',
      controls: [DemoSearchBar(onChanged: viewModel.onQueryChanged)],
      list: ValueListenableBuilder(
        valueListenable: viewModel.queryListenable,
        builder: (_, query, _) => ListSmith.sync(
          items: viewModel.items,
          searchBy: (item, query) => item.matches(query),
          query: query,
          grouping: Grouping.by(
            groupBy: viewModel.categoryOf,
            headerBuilder: (_, category) => _SectionHeader(label: category),
          ),
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, item, _) => DemoItemTile(item: item),
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
