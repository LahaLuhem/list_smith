import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

class const DemoSearchBar({required final ValueChanged<String> onChanged, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      PlatformSearchBar(hintText: 'Search items', onChanged: onChanged);
}
