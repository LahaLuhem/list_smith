import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/bool_knob.dart';
import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import '/features/core/widgets/slider_knob.dart';
import 'reload_view_model.dart';

/// Demonstrates the pull-to-refresh reload strategy. Scroll to load a few pages, then pull: with "Keep
/// scroll depth" on, every loaded page is re-fetched in place (watch the "load #" stamp bump); off, the
/// list resets to the first page. Inject a failure to see best-effort against all-or-nothing.
class ReloadView extends StatelessWidget {
  const ReloadView({super.key});

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
                const DemoIntro(
                  title: 'Reload to current depth',
                  description:
                      'Scroll to load a few pages, then pull to refresh. "Keep scroll depth" re-fetches '
                      'every loaded page in place (the "load #" stamp bumps); off resets to the first '
                      'page. Inject a failure to compare best-effort with all-or-nothing.',
                ),
                BoolKnob(
                  label: 'Keep scroll depth',
                  value: viewModel.keepDepth,
                  onChanged: (value) => viewModel.onKeepDepthToggled(value: value),
                ),
                SliderKnob(
                  label: 'Reload concurrency',
                  valueText: '${viewModel.concurrency}',
                  value: viewModel.concurrency.toDouble(),
                  min: 1,
                  max: 4,
                  divisions: 3,
                  onChanged: viewModel.onConcurrencyChanged,
                ),
                ValueListenableBuilder(
                  valueListenable: viewModel.injectFailures,
                  builder: (context, injectFailures, _) => BoolKnob(
                    label: 'Inject a failure on reload',
                    value: injectFailures,
                    onChanged: (value) => viewModel.onInjectFailuresToggled(value: value),
                  ),
                ),
                BoolKnob(
                  label: 'Atomic (all-or-nothing)',
                  value: viewModel.atomic,
                  onChanged: (value) => viewModel.onAtomicToggled(value: value),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListSmith.async(
              fetchPage: PageFetcher(viewModel.fetchPage),
              pageSize: 12,
              refresh: PullToRefresh(reload: viewModel.reload),
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
