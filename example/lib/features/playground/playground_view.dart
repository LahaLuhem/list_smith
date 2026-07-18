import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:material_ui/material_ui.dart' show Divider;
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'playground_view_model.dart';
import 'widgets/bool_knob.dart';
import 'widgets/slider_knob.dart';

/// A live playground: tweak the list's config with knobs and watch the preview react. `pageSize`
/// and the end policy are captured at construction, so the preview is keyed on them to force a fresh list.
/// The rest update in place.
class PlaygroundView extends StatelessWidget {
  const PlaygroundView({super.key});

  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: PlaygroundViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Playground',
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
                  title: 'Tweak the config live',
                  description:
                      'The source has a gap (an empty page mid-stream); raise "Empty pages before '
                      'end" to page past it.',
                ),
                SliderKnob(
                  label: 'Page size',
                  valueText: '${viewModel.pageSize}',
                  value: viewModel.pageSize.toDouble(),
                  min: 5,
                  max: 40,
                  divisions: 7,
                  onChanged: viewModel.onPageSizeChanged,
                ),
                SliderKnob(
                  label: 'Empty pages before end',
                  valueText: '${viewModel.emptyRunBeforeEnd}',
                  value: viewModel.emptyRunBeforeEnd.toDouble(),
                  min: 1,
                  max: 3,
                  divisions: 2,
                  onChanged: viewModel.onEmptyRunChanged,
                ),
                SliderKnob(
                  label: 'Fetch latency',
                  valueText: '${viewModel.latencyMs.round()} ms',
                  value: viewModel.latencyMs,
                  min: 0,
                  max: 2000,
                  divisions: 20,
                  onChanged: viewModel.onLatencyChanged,
                ),
                BoolKnob(
                  label: 'Pull to refresh',
                  value: viewModel.pullToRefresh,
                  onChanged: (value) => viewModel.onPullToRefreshToggled(value: value),
                ),
                BoolKnob(
                  label: 'Separators',
                  value: viewModel.separators,
                  onChanged: (value) => viewModel.onSeparatorsToggled(value: value),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListSmith.async(
              key: ValueKey((viewModel.pageSize, viewModel.emptyRunBeforeEnd)),
              fetchPage: PageFetcher(viewModel.fetchPage),
              pageSize: viewModel.pageSize,
              endPolicy: StopOnEmptyPagesPolicy(emptyRunBeforeEnd: viewModel.emptyRunBeforeEnd),
              refresh: viewModel.pullToRefresh ? const PullToRefresh() : const NoRefresh(),
              separatorBuilder: viewModel.separators ? (_, _) => const Divider(height: 1) : null,
              itemBuilder: (_, item, _) =>
                  PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle)),
            ),
          ),
        ],
      ),
    ),
  );
}
