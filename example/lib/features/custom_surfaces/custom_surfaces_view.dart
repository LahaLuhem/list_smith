import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/bool_knob.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'custom_surfaces_view_model.dart';
import 'widgets/custom_empty.dart';
import 'widgets/custom_end.dart';
import 'widgets/custom_error.dart';
import 'widgets/custom_loading.dart';
import 'widgets/custom_refresh.dart';

/// Every surface slot overridden with a platform-adaptive widget.
class const CustomSurfacesView({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => MVVM.builder(
    viewModel: CustomSurfacesViewModel(),
    viewBuilder: (context, viewModel) => DemoScaffold(
      title: 'Custom surfaces',
      body: Column(
        crossAxisAlignment: .stretch,
        children: [
          const Padding(
            padding: .all(16),
            child: Text('Pull to refresh to see the custom indicator.'),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: ValueListenableBuilder(
              valueListenable: viewModel.shouldInjectFailuresListenable,
              builder: (_, shouldInjectFailures, _) => BoolKnob(
                label: 'Inject fetch failures',
                subtitle: 'Shows the custom error and its Retry',
                value: shouldInjectFailures,
                onChanged: (value) => viewModel.onInjectFailuresToggled(value: value),
              ),
            ),
          ),
          Expanded(
            child: ListSmith.async(
              fetchPage: PageFetcher(viewModel.fetchPage),
              itemIdGetter: (item) => item.id,
              itemBuilder: (_, item, _) =>
                  PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle)),
              emptyBuilder: (_) => const CustomEmpty(),
              refresh: PullToRefresh(indicatorBuilder: (_, state) => CustomRefresh(state: state)),
              surfaces: AsyncListSurfaces(
                firstPageLoadingBuilder: (_) => const CustomLoading(),
                newPageLoadingBuilder: (_) => const CustomLoading(isCompact: true),
                firstPageErrorBuilder: (_, error, onRetry) =>
                    CustomError(error: error, onRetry: onRetry),
                newPageErrorBuilder: (_, error, onRetry) =>
                    CustomError(error: error, onRetry: onRetry, isCompact: true),
                noMoreItemsBuilder: (_) => const CustomEnd(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
