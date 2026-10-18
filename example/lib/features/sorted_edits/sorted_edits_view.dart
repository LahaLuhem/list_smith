import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/data/constants/const_theme.dart';
import '/features/core/widgets/demo_item_tile.dart';
import '/features/core/widgets/demo_scaffold.dart';
import '/features/core/widgets/title_dialog.dart';
import 'sorted_edits_view_model.dart';

/// `SortedBy` as `ListSmith.async`'s order, with `ListSmithController.upsertAsync`.
class const SortedEditsView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: SortedEditsViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Sorted edits',
      hint: 'Tap a row to rename it.',
      controls: [
        PlatformButton(
          onPressed: () => unawaited(
            showTitleDialog(
              context,
              heading: 'Add an item',
              hint: 'Title',
              onSaved: viewModel.onAdded,
            ),
          ),
          child: const Text('Add an item'),
        ),
      ],
      list: ListSmith.async(
        fetchPage: PageFetcher(viewModel.fetchPage),
        itemIdGetter: (item) => item.id,
        controller: viewModel.controller,
        order: viewModel.titleOrder,
        editTransition: ConstTheme.sizeEditTransition,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, item, _) => DemoItemTile(
          item: item,
          onTap: () => unawaited(
            showTitleDialog(
              context,
              heading: 'Rename',
              hint: item.title,
              onSaved: (title) => viewModel.onRenamed(item, title),
            ),
          ),
        ),
      ),
    ),
  );
}
