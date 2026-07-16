import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'grouping_view_model.dart';

/// Groups an in-memory list into labelled sections with `ListSmith.sync` + `Grouping.by`.
///
/// The source assigns a category per row cyclically, so the raw list is fully interleaved; sync
/// grouping buckets it into three contiguous sections. Typing narrows the list and the sections
/// re-form over the matches.
class GroupingView extends StatelessWidget {
  const GroupingView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: GroupingViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Grouping',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Padding(
            padding: .all(16),
            child: DemoIntro(
              title: 'Grouping.by',
              description:
                  'Splits the list into labelled sections. The source cycles three categories per '
                  'row, so the interleaved items bucket into three contiguous sections; the search '
                  'field narrows them and the sections re-form over the matches.',
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
                grouping: Grouping.by(
                  groupBy: viewModel.categoryOf,
                  headerBuilder: (_, category) => _SectionHeader(label: category),
                ),
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

/// The section header stacked above each group's first item.
class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .fromLTRB(16, 16, 16, 4),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
  );
}
