import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_item_tile.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'cursor_feed_view_model.dart';

/// `PageFetcher.withSignal` plus `StopOnNullSignalPolicy`, where the end signal doubles as the driving
/// cursor.
class const CursorFeedView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: CursorFeedViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Cursor feed',
      list: ListSmith.async(
        fetchPage: PageFetcher.withSignal(viewModel.cursorFetchPage),
        itemIdGetter: (item) => item.id,
        endPolicy: const StopOnNullSignalPolicy(),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, item, _) => DemoItemTile(item: item),
      ),
    ),
  );
}
