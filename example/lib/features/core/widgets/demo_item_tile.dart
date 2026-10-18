import 'package:flutter/widgets.dart';
import 'package:platform_adaptive_widgets/platform_adaptive_widgets.dart';

import '../data/models/demo_item.dart';

class const DemoItemTile({required final DemoItem item, final VoidCallback? onTap, super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      PlatformListTile(title: Text(item.title), subtitle: Text(item.subtitle), onTap: onTap);
}
