// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_member_subscription.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1449 A4 — a member's subscription share, and whether it may be set.

@ProviderFor(memberSubscriptions)
final memberSubscriptionsProvider = MemberSubscriptionsProvider._();

/// #1449 A4 — a member's subscription share, and whether it may be set.

final class MemberSubscriptionsProvider
    extends
        $FunctionalProvider<
          MemberSubscriptions,
          MemberSubscriptions,
          MemberSubscriptions
        >
    with $Provider<MemberSubscriptions> {
  /// #1449 A4 — a member's subscription share, and whether it may be set.
  MemberSubscriptionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberSubscriptionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberSubscriptionsHash();

  @$internal
  @override
  $ProviderElement<MemberSubscriptions> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemberSubscriptions create(Ref ref) {
    return memberSubscriptions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemberSubscriptions value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemberSubscriptions>(value),
    );
  }
}

String _$memberSubscriptionsHash() =>
    r'755e6c3fcfaceebd065711b8a4c0508356b10ea6';
