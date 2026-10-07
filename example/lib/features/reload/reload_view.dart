import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/bool_knob.dart';
import '/features/core/widgets/demo_scaffold.dart';
import '/features/core/widgets/slider_knob.dart';
import 'reload_view_model.dart';

/// The `Reload` strategies on `PullToRefresh`, plus a `ListSmithController` driving the same reload
/// with no gesture.
class const ReloadView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: ReloadViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Reload',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          Padding(
            padding: const .all(16),
            child: Column(
              crossAxisAlignment: .stretch,
              spacing: 8,
              children: [
                const Text('Scroll down a few pages, then pull to refresh.'),
                BoolKnob(
                  label: 'Keep scroll depth',
                  subtitle: 'Reloads every loaded page, not just the 1st',
                  value: viewModel.keepDepth,
                  onChanged: (value) => viewModel.onKeepDepthToggled(value: value),
                ),
                SliderKnob(
                  label: 'Reload concurrency',
                  subtitle: 'Pages reloaded at once',
                  valueText: '${viewModel.concurrency}',
                  value: viewModel.concurrency.toDouble(),
                  min: 1,
                  max: 4,
                  divisions: 3,
                  onChanged: viewModel.onConcurrencyChanged,
                ),
                ValueListenableBuilder(
                  valueListenable: viewModel.shouldInjectFailuresListenable,
                  builder: (context, shouldInjectFailures, _) => BoolKnob(
                    label: 'Inject a failure on reload',
                    subtitle: 'The 1st page fails to reload',
                    value: shouldInjectFailures,
                    onChanged: (value) => viewModel.onInjectFailuresToggled(value: value),
                  ),
                ),
                BoolKnob(
                  label: 'Atomic (all-or-nothing)',
                  subtitle: 'One failure keeps all the old pages',
                  value: viewModel.atomic,
                  onChanged: (value) => viewModel.onAtomicToggled(value: value),
                ),
                ValueListenableBuilder(
                  valueListenable: viewModel.isRefreshingListenable,
                  builder: (context, isRefreshing, _) => PlatformButton(
                    onPressed: viewModel.onRefreshPressed,
                    isEnabled: !isRefreshing,
                    child: Text(isRefreshing ? 'Refreshing…' : 'Refresh from code'),
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: viewModel.lastExceptionListenable,
                  builder: (_, lastException, _) =>
                      lastException == null ? const SizedBox.shrink() : Text('$lastException'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListSmith.async(
              fetchPage: PageFetcher(viewModel.fetchPage),
              itemIdGetter: (item) => item.id,
              pageSize: 12,
              refresh: PullToRefresh(reload: viewModel.reload),
              controller: viewModel.controller,
              observer: viewModel.observer,
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
