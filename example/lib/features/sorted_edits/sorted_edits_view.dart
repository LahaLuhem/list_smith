import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

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
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .all(16),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                const Text('Tap a row to rename it.'),
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
            ),
          ),
          Expanded(
            child: ListSmith.async(
              fetchPage: PageFetcher(viewModel.fetchPage),
              itemIdGetter: (item) => item.id,
              controller: viewModel.controller,
              order: viewModel.titleOrder,
              editTransition: EditTransition(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    SizeTransition(sizeFactor: animation, child: child),
              ),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, item, _) => PlatformListTile(
                title: Text(item.title),
                subtitle: Text(item.subtitle),
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
        ],
      ),
    ),
  );
}
