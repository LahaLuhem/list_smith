import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider, Icons;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:platform_icons/platform_icons.dart' show PlatformIcons;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/data/constants/const_theme.dart';
import '/features/core/data/models/demo_item.dart';
import '/features/core/widgets/bool_knob.dart';
import '/features/core/widgets/demo_item_tile.dart';
import '/features/core/widgets/demo_scaffold.dart';
import '/features/core/widgets/title_sheet.dart';
import 'edits_view_model.dart';

/// `ListSmithController.upsertAsync` and `removeAsync`, behind flutter_slidable's swipe actions and a
/// row menu.
class const EditsView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: EditsViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Edits',
      hint: 'Swipe a row left for Rename and Delete, or all the way to delete it.',
      controls: [
        ValueListenableBuilder(
          valueListenable: viewModel.shouldFailSavesListenable,
          builder: (context, shouldFailSaves, _) => BoolKnob(
            label: 'Saves fail',
            subtitle: 'Every save fails after a moment, and its edit rolls back',
            value: shouldFailSaves,
            onChanged: (value) => viewModel.onSavesFailToggled(value: value),
          ),
        ),
        PlatformButton(
          onPressed: viewModel.onAddPressed,
          emphasis: .medium,
          child: const Text('Add an item'),
        ),
      ],
      list: ListSmith.async(
        fetchPage: PageFetcher.withSignal(viewModel.fetchPage),
        endPolicy: const StopOnNullSignalPolicy(),
        itemIdGetter: (item) => item.id,
        controller: viewModel.controller,
        editTransition: ConstTheme.sizeEditTransition,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, item, _) => _EditableRow(item: item, viewModel: viewModel),
      ),
    ),
  );
}

class const _EditableRow({required final DemoItem item, required final EditsViewModel viewModel})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    void rename() => unawaited(
      showTitleSheet(
        context,
        heading: 'Rename',
        hint: item.title,
        onSaved: (title) => viewModel.onRenamed(item, title),
      ),
    );
    void delete() => viewModel.onDeleted(item);

    return Slidable(
      key: ValueKey(item.id), // DismissiblePane asserts without one
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        dismissible: DismissiblePane(onDismissed: delete),
        children: [
          SlidableAction(
            onPressed: (_) => rename(),
            backgroundColor: ConstTheme.seedColor,
            icon: _iconOf(PlatformIcons.pencil),
            label: 'Rename',
          ),
          SlidableAction(
            onPressed: (_) => delete(),
            backgroundColor: _deleteColour,
            icon: _iconOf(PlatformIcons.delete),
            label: 'Delete',
          ),
        ],
      ),
      child: DemoItemTile(
        item: item,
        // A swipe shouldn't be the only way to these.
        trailing: PlatformActionsMenu(
          builder: (_, onPressed) => PlatformButton.iconOnly(
            onPressed: onPressed,
            emphasis: .low,
            // No more_vert paired with iOS's ellipsis in platform_icons, so fall back to platformValue.
            icon: Icon(
              platformValue(material: Icons.more_vert, cupertino: CupertinoIcons.ellipsis),
            ),
            label: 'More',
          ),
          actions: {
            PlatformMenuAction.normal(
              label: 'Rename',
              iconData: _iconOf(PlatformIcons.pencil),
              onPressed: rename,
            ),
            PlatformMenuAction.delete(
              label: 'Delete',
              iconData: _iconOf(PlatformIcons.delete),
              confirmMessage: 'This deletes ${item.title}.',
              onPressed: delete,
            ),
          },
        ),
      ),
    );
  }

  static IconData _iconOf(PlatformIcons icon) =>
      platformValue(material: icon.material, cupertino: icon.cupertino);

  static const _deleteColour = Color(0xFFDC2626);
}
