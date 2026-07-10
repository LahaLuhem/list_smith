import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:list_smith/list_smith.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';
import 'package:pmvvm/mvvm_builder.widget.dart';

import '/features/core/widgets/demo_intro.dart';
import '/features/core/widgets/demo_scaffold.dart';
import 'custom_surfaces_view_model.dart';
import 'widgets/custom_empty.dart';
import 'widgets/custom_end.dart';
import 'widgets/custom_error.dart';
import 'widgets/custom_loading.dart';
import 'widgets/custom_refresh.dart';

/// Demonstrates replacing every neutral surface with a platform-adaptive one,
/// and (via the failure toggle) the error + retry path.
class CustomSurfacesView extends StatelessWidget {
  const CustomSurfacesView({super.key});

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
            child: DemoIntro(
              title: 'Overriding the defaults',
              description:
                  'Every surface (loading, error, empty, end, and the pull indicator) is replaced '
                  'with a platform-adaptive one. Flip failures on to see the error and retry path.',
            ),
          ),
          _FailureToggle(
            injectFailures: viewModel.injectFailures,
            onChanged: (value) => viewModel.onFailureToggled(value: value),
          ),
          Expanded(
            child: ListSmith.async(
              fetchPage: viewModel.fetchPage,
              itemBuilder: (_, item, _) =>
                  PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle)),
              emptyBuilder: (_) => const CustomEmpty(),
              surfaces: AsyncListSurfaces(
                firstPageLoadingBuilder: (_) => const CustomLoading(),
                newPageLoadingBuilder: (_) => const CustomLoading(compact: true),
                firstPageErrorBuilder: (_, error, onRetry) =>
                    CustomError(error: error, onRetry: onRetry),
                newPageErrorBuilder: (_, error, onRetry) =>
                    CustomError(error: error, onRetry: onRetry, compact: true),
                noMoreItemsBuilder: (_) => const CustomEnd(),
                refreshBuilder: (_, child, state) => CustomRefresh(state: state, child: child),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// A labelled switch that toggles injected fetch failures.
class _FailureToggle extends StatelessWidget {
  final ValueListenable<bool> injectFailures;
  final ValueChanged<bool> onChanged;

  const _FailureToggle({required this.injectFailures, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const .symmetric(horizontal: 16),
    child: Row(
      children: [
        const Expanded(child: Text('Inject fetch failures')),
        ValueListenableBuilder(
          valueListenable: injectFailures,
          builder: (_, value, _) => PlatformSwitch(value: value, onChanged: onChanged),
        ),
      ],
    ),
  );
}
