part 'policies/fail_on_unordered_policy.dart';
part 'policies/repair_headers_policy.dart';

/// What an async list does when a group key comes back after its section ended.
@Deprecated(
  'Groups gather on their own now. Remove the orderPolicy argument, it goes at the next major.',
)
sealed class const GroupOrderPolicy() {
  /// Const base constructor.
  @Deprecated(
    'Groups gather on their own now. Remove the orderPolicy argument, it goes at the next major.',
  )
  this;
}
