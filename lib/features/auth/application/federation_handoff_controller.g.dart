// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'federation_handoff_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FederationHandoffController)
final federationHandoffControllerProvider =
    FederationHandoffControllerProvider._();

final class FederationHandoffControllerProvider
    extends
        $NotifierProvider<FederationHandoffController, FederationHandoffState> {
  FederationHandoffControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'federationHandoffControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$federationHandoffControllerHash();

  @$internal
  @override
  FederationHandoffController create() => FederationHandoffController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FederationHandoffState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FederationHandoffState>(value),
    );
  }
}

String _$federationHandoffControllerHash() =>
    r'f3b733fe00ff11bccf66a64fa38f038c73cc55d6';

abstract class _$FederationHandoffController
    extends $Notifier<FederationHandoffState> {
  FederationHandoffState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<FederationHandoffState, FederationHandoffState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<FederationHandoffState, FederationHandoffState>,
              FederationHandoffState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether this build can run the handoff at all (it owns the callback).

@ProviderFor(federationHandoffAvailable)
final federationHandoffAvailableProvider =
    FederationHandoffAvailableProvider._();

/// Whether this build can run the handoff at all (it owns the callback).

final class FederationHandoffAvailableProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Whether this build can run the handoff at all (it owns the callback).
  FederationHandoffAvailableProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'federationHandoffAvailableProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$federationHandoffAvailableHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return federationHandoffAvailable(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$federationHandoffAvailableHash() =>
    r'd48b828665f37548359d54dafc162863f5e680b1';

/// Where "Continue with Deskilo" leads, for the one-sentence explanation.

@ProviderFor(federationDestination)
final federationDestinationProvider = FederationDestinationProvider._();

/// Where "Continue with Deskilo" leads, for the one-sentence explanation.

final class FederationDestinationProvider
    extends
        $FunctionalProvider<
          AsyncValue<FederationDestination?>,
          FederationDestination?,
          FutureOr<FederationDestination?>
        >
    with
        $FutureModifier<FederationDestination?>,
        $FutureProvider<FederationDestination?> {
  /// Where "Continue with Deskilo" leads, for the one-sentence explanation.
  FederationDestinationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'federationDestinationProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$federationDestinationHash();

  @$internal
  @override
  $FutureProviderElement<FederationDestination?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<FederationDestination?> create(Ref ref) {
    return federationDestination(ref);
  }
}

String _$federationDestinationHash() =>
    r'524bf0632a1edeac580385696351647d884511de';
