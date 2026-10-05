import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/bool_knob.dart';
import '/features/core/widgets/demo_scaffold.dart';
import '/features/core/widgets/event_log_panel.dart';
import 'observer_view_model.dart';

/// `ListSmith.async` wired to a `ListSmithObserver` whose events stream into an `EventLogPanel`.
class const ObserverView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: ObserverViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Observer',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Padding(
            padding: .all(16),
            child: Text('Scroll, pull or search, and watch the log.'),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: ValueListenableBuilder(
              valueListenable: viewModel.shouldInjectFailuresListenable,
              builder: (_, shouldInjectFailures, _) => BoolKnob(
                label: 'Inject failures',
                subtitle: 'Every fetch fails',
                value: shouldInjectFailures,
                onChanged: (value) => viewModel.onInjectFailuresToggled(value: value),
              ),
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: PlatformSearchBar(hintText: 'Search items', onChanged: viewModel.onQueryChanged),
          ),
          Expanded(
            child: ValueListenableBuilder(
              valueListenable: viewModel.queryListenable,
              builder: (_, query, _) => ListSmith.async(
                fetchPage: PageFetcher(viewModel.fetchPage),
                itemIdGetter: (item) => item.id,
                search: AsyncSearch(fetchPage: SearchPageFetcher(viewModel.searchFetchPage)),
                observer: viewModel.observer,
                query: query,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, item, _) =>
                    PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle)),
              ),
            ),
          ),
          EventLogPanel(events: viewModel.eventsListenable, onClear: viewModel.clearLog),
        ],
      ),
    ),
  );
}
