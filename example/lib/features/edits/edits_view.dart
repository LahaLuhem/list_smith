import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart' show PlatformIcons;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/data/constants/const_theme.dart';
import '/features/core/data/models/demo_item.dart';
import '/features/core/widgets/bool_knob.dart';
import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'edits_view_model.dart';

/// `ListSmithController.upsert` and `remove`, behind flutter_slidable's swipe actions.
class const EditsView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: EditsViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Edits',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .all(16),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                const DemoIntro(
                  title: 'Edit loaded items',
                  description:
                      'Swipe a row left for Rename and Delete, or all the way to delete it in one go. '
                      '"Add an item" puts a new one on top. Each change goes through upsert() or '
                      'remove(), with no refetch, and a row they add or take grows in or shrinks '
                      'out. With deletes failing, Delete leaves the row alone, but a full swipe still '
                      'removes it, since the row has to go before the store answers. Pull to refresh '
                      'and it comes back.',
                ),
                ValueListenableBuilder(
                  valueListenable: viewModel.shouldFailDeletesListenable,
                  builder: (context, shouldFailDeletes, _) => BoolKnob(
                    label: 'Deletes fail',
                    value: shouldFailDeletes,
                    onChanged: (value) => viewModel.onDeletesFailToggled(value: value),
                  ),
                ),
                PlatformButton(onPressed: viewModel.onAddPressed, child: const Text('Add an item')),
              ],
            ),
          ),
          Expanded(
            child: ListSmith.async(
              fetchPage: PageFetcher.withSignal(viewModel.fetchPage),
              endPolicy: const StopOnNullSignalPolicy(),
              itemIdGetter: (item) => item.id,
              controller: viewModel.controller,
              editTransition: EditTransition(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    SizeTransition(sizeFactor: animation, child: child),
              ),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, item, _) => _EditableRow(item: item, viewModel: viewModel),
            ),
          ),
        ],
      ),
    ),
  );
}

class const _EditableRow({required final DemoItem item, required final EditsViewModel viewModel})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Slidable(
    key: ValueKey(item.id), // DismissiblePane asserts without one
    endActionPane: ActionPane(
      motion: const DrawerMotion(),
      dismissible: DismissiblePane(onDismissed: () => viewModel.onDismissed(item)),
      children: [
        SlidableAction(
          onPressed: _onRenamePressed,
          backgroundColor: ConstTheme.seedColor,
          icon: _iconOf(PlatformIcons.pencil),
          label: 'Rename',
        ),
        SlidableAction(
          onPressed: (_) => viewModel.onDeletePressed(item),
          backgroundColor: _deleteColour,
          icon: _iconOf(PlatformIcons.delete),
          label: 'Delete',
        ),
      ],
    ),
    child: PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle)),
  );

  Future<void> _onRenamePressed(BuildContext context) async {
    var title = '';
    final newTitle = await showPlatformAlertDialog<String>(
      context: context,
      title: const Text('Rename'),
      content: PlatformTextField(
        hintText: item.title,
        autofocus: true,
        onChanged: (value) => title = value,
      ),
      actions: [
        PlatformDialogAction(
          onPressed: (context) => Navigator.maybeOf(context)?.pop(),
          child: const Text('Cancel'),
        ),
        PlatformDialogAction(
          isDefaultAction: true,
          onPressed: (context) => Navigator.maybeOf(context)?.pop(title),
          child: const Text('Save'),
        ),
      ],
    );
    if (newTitle != null) viewModel.onRenamed(item, newTitle);
  }

  static IconData _iconOf(PlatformIcons icon) =>
      platformValue(material: icon.material, cupertino: icon.cupertino);

  static const _deleteColour = Color(0xFFDC2626);
}
