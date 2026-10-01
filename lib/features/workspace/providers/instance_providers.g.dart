// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'instance_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// #1829 — the instance owner and delegates (0314).

@ProviderFor(instanceRepository)
final instanceRepositoryProvider = InstanceRepositoryProvider._();

/// #1829 — the instance owner and delegates (0314).

final class InstanceRepositoryProvider
    extends
        $FunctionalProvider<
          InstanceRepository,
          InstanceRepository,
          InstanceRepository
        >
    with $Provider<InstanceRepository> {
  /// #1829 — the instance owner and delegates (0314).
  InstanceRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'instanceRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$instanceRepositoryHash();

  @$internal
  @override
  $ProviderElement<InstanceRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InstanceRepository create(Ref ref) {
    return instanceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstanceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstanceRepository>(value),
    );
  }
}

String _$instanceRepositoryHash() =>
    r'f51cf25b7ed581904fce0c9af553e590c2a78e62';

/// Who answers for this installation, as the server says now. Refreshed by
/// invalidation after a delegation, a withdrawal or a claim.

@ProviderFor(instanceResponsibles)
final instanceResponsiblesProvider = InstanceResponsiblesProvider._();

/// Who answers for this installation, as the server says now. Refreshed by
/// invalidation after a delegation, a withdrawal or a claim.

final class InstanceResponsiblesProvider
    extends
        $FunctionalProvider<
          AsyncValue<InstanceResponsibles>,
          InstanceResponsibles,
          FutureOr<InstanceResponsibles>
        >
    with
        $FutureModifier<InstanceResponsibles>,
        $FutureProvider<InstanceResponsibles> {
  /// Who answers for this installation, as the server says now. Refreshed by
  /// invalidation after a delegation, a withdrawal or a claim.
  InstanceResponsiblesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'instanceResponsiblesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$instanceResponsiblesHash();

  @$internal
  @override
  $FutureProviderElement<InstanceResponsibles> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<InstanceResponsibles> create(Ref ref) {
    return instanceResponsibles(ref);
  }
}

String _$instanceResponsiblesHash() =>
    r'2f981ff463cc26c6bd75edc41df3e7f3f2aa95c5';

/// What the owner asks of the instance's roles (#1829).

@ProviderFor(instanceRoles)
final instanceRolesProvider = InstanceRolesProvider._();

/// What the owner asks of the instance's roles (#1829).

final class InstanceRolesProvider
    extends $FunctionalProvider<InstanceRoles, InstanceRoles, InstanceRoles>
    with $Provider<InstanceRoles> {
  /// What the owner asks of the instance's roles (#1829).
  InstanceRolesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'instanceRolesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$instanceRolesHash();

  @$internal
  @override
  $ProviderElement<InstanceRoles> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  InstanceRoles create(Ref ref) {
    return instanceRoles(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InstanceRoles value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InstanceRoles>(value),
    );
  }
}

String _$instanceRolesHash() => r'a2ac12d7646e1abe7a6a11c9f51dda9621228c50';
