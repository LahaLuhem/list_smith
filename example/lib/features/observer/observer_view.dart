import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'observer_view_model.dart';
import 'widgets/event_log_panel.dart';

/// `ListSmith.async` wired to a `ListSmithObserver`: every lifecycle event (page load, error, refresh,
/// query-committed, mode change) streams into a live log below the list. Scroll to page, pull to
/// refresh, search, or flip "Inject failures" to make each event fire.
class ObserverView extends StatelessWidget {
  const ObserverView({super.key});

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
            child: DemoIntro(
              title: 'ListSmith.async + observer',
              description:
                  'An injected ListSmithObserver reports lifecycle events without exposing the '
                  'controller. Scroll to load pages, pull to refresh, search, or inject a failure; '
                  'each event lands in the log below.',
            ),
          ),
          _InjectFailureToggle(
            shouldInjectFailures: viewModel.shouldInjectFailuresListenable,
            onChanged: (value) => viewModel.onInjectFailuresToggled(value: value),
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
                searchFetchPage: SearchPageFetcher(viewModel.searchFetchPage),
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

/// A labelled switch that makes the next fetch fail, so the observer's error event can be seen.
class _InjectFailureToggle extends StatelessWidget {
  final ValueListenable<bool> shouldInjectFailures;
  final ValueChanged<bool> onChanged;

  const _InjectFailureToggle({required this.shouldInjectFailures, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(horizontal: 16),
    child: Row(
      children: [
        const Expanded(child: Text('Inject failures')),
        ValueListenableBuilder(
          valueListenable: shouldInjectFailures,
          builder: (_, value, _) => PlatformSwitch(value: value, onChanged: onChanged),
        ),
      ],
    ),
  );
}
