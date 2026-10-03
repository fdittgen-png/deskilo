// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'set_member_customer_capacity.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1916 — the command that states a member's customer capacity.

@ProviderFor(memberCustomerCapacities)
final memberCustomerCapacitiesProvider = MemberCustomerCapacitiesProvider._();

/// #1916 — the command that states a member's customer capacity.

final class MemberCustomerCapacitiesProvider
    extends
        $FunctionalProvider<
          MemberCustomerCapacities,
          MemberCustomerCapacities,
          MemberCustomerCapacities
        >
    with $Provider<MemberCustomerCapacities> {
  /// #1916 — the command that states a member's customer capacity.
  MemberCustomerCapacitiesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'memberCustomerCapacitiesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$memberCustomerCapacitiesHash();

  @$internal
  @override
  $ProviderElement<MemberCustomerCapacities> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  MemberCustomerCapacities create(Ref ref) {
    return memberCustomerCapacities(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MemberCustomerCapacities value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MemberCustomerCapacities>(value),
    );
  }
}

String _$memberCustomerCapacitiesHash() =>
    r'e480c804641c5adcb515a867c2668c83b5fb836f';
