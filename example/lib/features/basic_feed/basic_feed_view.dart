import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_scaffold.dart';
import 'basic_feed_view_model.dart';

/// `ListSmith.async` with nothing but a fetcher and an item builder, so every surface is a neutral default.
class const BasicFeedView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: BasicFeedViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Basic feed',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Padding(
            padding: .all(16),
            child: Text('Pull to refresh. The list ends on the 1st empty page.'),
          ),
          Expanded(
            child: ListSmith.async(
              fetchPage: PageFetcher(viewModel.fetchPage),
              itemIdGetter: (item) => item.id,
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
