import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/bool_knob.dart';
import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import '/features/core/widgets/event_log_panel.dart';
import 'cache_routing_view_model.dart';

/// A caching repository in front of `ListSmith.async`, routed on `PageRequest.trigger`: a scroll is
/// served from cache, a pull-to-refresh bypasses it. Each row shows the fetch that produced it, so
/// turn the knob off and pull again to watch the same stale rows come back.
class CacheRoutingView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: CacheRoutingViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Cache routing',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Padding(
            padding: .all(16),
            child: DemoIntro(
              title: 'Routing on PageRequest.trigger',
              description:
                  'The fetch bypasses its cache for a refresh or a retry, and serves a scroll from '
                  'it. Rows are stamped with the fetch that produced them: pull to refresh and the '
                  'stamps change, scroll back and they do not.',
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: ValueListenableBuilder(
              valueListenable: viewModel.shouldRouteOnTriggerListenable,
              builder: (_, routeOnTrigger, _) => BoolKnob(
                label: 'Route on trigger',
                value: routeOnTrigger,
                onChanged: (value) => viewModel.onRouteOnTriggerToggled(value: value),
              ),
            ),
          ),
          Expanded(
            child: ListSmith.async(
              fetchPage: PageFetcher(viewModel.fetchPage),
              pageSize: 12,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, item, _) =>
                  PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle)),
            ),
          ),
          _ClearCacheButton(onPressed: viewModel.clearCache),
          EventLogPanel(events: viewModel.logListenable, onClear: viewModel.clearLog),
        ],
      ),
    ),
  );
}

/// Empties the demo's cache, so the next fetch of each page goes to the network again.
class _ClearCacheButton extends StatelessWidget {
  final VoidCallback onPressed;

  const new({required this.onPressed});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(horizontal: 16),
    child: Row(
      children: [
        const Expanded(child: Text('Cached pages')),
        PlatformButton(
          onPressed: onPressed,
          materialButtonVariant: .text,
          child: const Text('Clear cache'),
        ),
      ],
    ),
  );
}
