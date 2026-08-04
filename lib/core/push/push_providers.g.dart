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

String _$pushConnectorHash() => r'b7ba368ba7ffc1ce171ae41d57b2a0a5e6251340';

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

/// Starts the push pipeline once per app run (#72/#428). Watched from
/// the shell; a missing distributor or platform just means local-only.

@ProviderFor(pushBootstrap)
final pushBootstrapProvider = PushBootstrapProvider._();

/// Starts the push pipeline once per app run (#72/#428). Watched from
/// the shell; a missing distributor or platform just means local-only.

final class PushBootstrapProvider
    extends
        $FunctionalProvider<
          AsyncValue<PushService?>,
          PushService?,
          FutureOr<PushService?>
        >
    with $FutureModifier<PushService?>, $FutureProvider<PushService?> {
  /// Starts the push pipeline once per app run (#72/#428). Watched from
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
  $FutureProviderElement<PushService?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PushService?> create(Ref ref) {
    return pushBootstrap(ref);
  }
}

String _$pushBootstrapHash() => r'a680a255773b2067e10fe965b3687b597a488246';
