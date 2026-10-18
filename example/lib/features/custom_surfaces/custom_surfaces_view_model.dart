import 'package:list_smith/list_smith.dart';
import 'package:pmvvm/pmvvm.dart';

import '/features/core/data/models/demo_item.dart';
import '/features/core/mixins/failure_injection_mixin.dart';
import '/features/core/repos/demo_repository.dart';

final class CustomSurfacesViewModel() extends ViewModel with FailureInjectionMixin {
  final _repository = DemoRepository();

  Future<List<DemoItem>> fetchPage(PageRequest request) =>
      withInjectedFailures(_repository.fetchPage(request.pageIndex, request.pageSize));
}
