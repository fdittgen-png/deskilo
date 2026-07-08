// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'push_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pushConnector)
final pushConnectorProvider = PushConnectorProvider._();

final class PushConnectorProvider
    extends $FunctionalProvider<PushConnector, PushConnector, PushConnector>
    with $Provider<PushConnector> {
  PushConnectorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushConnectorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushConnectorHash();

  @$internal
  @override
  $ProviderElement<PushConnector> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PushConnector create(Ref ref) {
    return pushConnector(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushConnector value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushConnector>(value),
    );
  }
}

String _$pushConnectorHash() => r'6c30eca18416b89aaceb6a52f2d2857d256690ef';

@ProviderFor(pushEndpointRepository)
final pushEndpointRepositoryProvider = PushEndpointRepositoryProvider._();

final class PushEndpointRepositoryProvider
    extends
        $FunctionalProvider<
          PushEndpointRepository,
          PushEndpointRepository,
          PushEndpointRepository
        >
    with $Provider<PushEndpointRepository> {
  PushEndpointRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushEndpointRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushEndpointRepositoryHash();

  @$internal
  @override
  $ProviderElement<PushEndpointRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PushEndpointRepository create(Ref ref) {
    return pushEndpointRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PushEndpointRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PushEndpointRepository>(value),
    );
  }
}

String _$pushEndpointRepositoryHash() =>
    r'374d9c98e39e72e19b16aafcfab4526ee97fe635';

/// Starts the UnifiedPush pipeline once per app run (#72). Watched from
/// the shell; a missing distributor or platform just means local-only.

@ProviderFor(pushBootstrap)
final pushBootstrapProvider = PushBootstrapProvider._();

/// Starts the UnifiedPush pipeline once per app run (#72). Watched from
/// the shell; a missing distributor or platform just means local-only.

final class PushBootstrapProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Starts the UnifiedPush pipeline once per app run (#72). Watched from
  /// the shell; a missing distributor or platform just means local-only.
  PushBootstrapProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushBootstrapProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushBootstrapHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return pushBootstrap(ref);
  }
}

String _$pushBootstrapHash() => r'ef54a0276e5e2e8c26216e48d3efe98c1dc1b660';
