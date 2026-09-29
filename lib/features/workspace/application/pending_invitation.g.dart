// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_invitation.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pendingInvitationStore)
final pendingInvitationStoreProvider = PendingInvitationStoreProvider._();

final class PendingInvitationStoreProvider
    extends
        $FunctionalProvider<
          PendingInvitationStore,
          PendingInvitationStore,
          PendingInvitationStore
        >
    with $Provider<PendingInvitationStore> {
  PendingInvitationStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingInvitationStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingInvitationStoreHash();

  @$internal
  @override
  $ProviderElement<PendingInvitationStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PendingInvitationStore create(Ref ref) {
    return pendingInvitationStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingInvitationStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingInvitationStore>(value),
    );
  }
}

String _$pendingInvitationStoreHash() =>
    r'9d8642beeaeb18e0ac2a1786c6eddb4c8f772038';

@ProviderFor(pendingInvitations)
final pendingInvitationsProvider = PendingInvitationsProvider._();

final class PendingInvitationsProvider
    extends
        $FunctionalProvider<
          PendingInvitations,
          PendingInvitations,
          PendingInvitations
        >
    with $Provider<PendingInvitations> {
  PendingInvitationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingInvitationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingInvitationsHash();

  @$internal
  @override
  $ProviderElement<PendingInvitations> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PendingInvitations create(Ref ref) {
    return pendingInvitations(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PendingInvitations value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PendingInvitations>(value),
    );
  }
}

String _$pendingInvitationsHash() =>
    r'1acb4169bf3dcff7ad2a55102b45cdf2e4b56652';

@ProviderFor(arrivedInvitations)
final arrivedInvitationsProvider = ArrivedInvitationsProvider._();

final class ArrivedInvitationsProvider
    extends
        $FunctionalProvider<
          ArrivedInvitations,
          ArrivedInvitations,
          ArrivedInvitations
        >
    with $Provider<ArrivedInvitations> {
  ArrivedInvitationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'arrivedInvitationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$arrivedInvitationsHash();

  @$internal
  @override
  $ProviderElement<ArrivedInvitations> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ArrivedInvitations create(Ref ref) {
    return arrivedInvitations(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ArrivedInvitations value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ArrivedInvitations>(value),
    );
  }
}

String _$arrivedInvitationsHash() =>
    r'1024c6a7e944ff3f73e0086c1b179531e94db1e7';
