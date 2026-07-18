import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'cursor_feed_view_model.dart';

/// Cursor-driven pagination: each fetch is handed the cursor the previous page returned (null for the
/// first page), and `StopOnNullSignalPolicy` ends the list when the source returns a null cursor.
/// Built on `PageFetcher.withSignal`, whose end signal doubles as the driving cursor.
class CursorFeedView extends StatelessWidget {
  const CursorFeedView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: CursorFeedViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Cursor feed',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Padding(
            padding: .all(16),
            child: DemoIntro(
              title: 'Cursor pagination',
              description:
                  'Each fetch is driven by the cursor the previous page returned, not a page index. '
                  'StopOnNullSignalPolicy ends the list when the source returns a null cursor.',
            ),
          ),
          Expanded(
            child: ListSmith.async(
              fetchPage: PageFetcher.withSignal(viewModel.cursorFetchPage),
              endPolicy: const StopOnNullSignalPolicy(),
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, item, _) =>
                  PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle)),
            ),
          ),
        ],
      ),
    ),
  );
}
