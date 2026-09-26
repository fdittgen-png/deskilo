// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backend_settings.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(backendSettingsStore)
final backendSettingsStoreProvider = BackendSettingsStoreProvider._();

final class BackendSettingsStoreProvider
    extends
        $FunctionalProvider<
          BackendSettingsStore,
          BackendSettingsStore,
          BackendSettingsStore
        >
    with $Provider<BackendSettingsStore> {
  BackendSettingsStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendSettingsStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendSettingsStoreHash();

  @$internal
  @override
  $ProviderElement<BackendSettingsStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackendSettingsStore create(Ref ref) {
    return backendSettingsStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackendSettingsStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackendSettingsStore>(value),
    );
  }
}

String _$backendSettingsStoreHash() =>
    r'9ab7f19caf75000de153aed360eecf75d7969a4a';

/// #1651 — the URL this PROCESS was initialised with, which is what every
/// RPC still targets whatever the store now holds. Empty when the process
/// was not booted through `initializeApp` (tests, Demo).

@ProviderFor(bootedBackendUrl)
final bootedBackendUrlProvider = BootedBackendUrlProvider._();

/// #1651 — the URL this PROCESS was initialised with, which is what every
/// RPC still targets whatever the store now holds. Empty when the process
/// was not booted through `initializeApp` (tests, Demo).

final class BootedBackendUrlProvider
    extends $FunctionalProvider<String, String, String>
    with $Provider<String> {
  /// #1651 — the URL this PROCESS was initialised with, which is what every
  /// RPC still targets whatever the store now holds. Empty when the process
  /// was not booted through `initializeApp` (tests, Demo).
  BootedBackendUrlProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'bootedBackendUrlProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$bootedBackendUrlHash();

  @$internal
  @override
  $ProviderElement<String> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String create(Ref ref) {
    return bootedBackendUrl(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$bootedBackendUrlHash() => r'bb161abb6eaa7e7f6b015bd8ac32a274f13994f9';

/// The endpoint in force: the stored one, or the compiled default.
/// Startup reads the store directly (before any provider exists); this
/// provider is what Settings displays and edits.

@ProviderFor(ActiveBackend)
final activeBackendProvider = ActiveBackendProvider._();

/// The endpoint in force: the stored one, or the compiled default.
/// Startup reads the store directly (before any provider exists); this
/// provider is what Settings displays and edits.
final class ActiveBackendProvider
    extends $AsyncNotifierProvider<ActiveBackend, BackendEndpoint> {
  /// The endpoint in force: the stored one, or the compiled default.
  /// Startup reads the store directly (before any provider exists); this
  /// provider is what Settings displays and edits.
  ActiveBackendProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeBackendProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeBackendHash();

  @$internal
  @override
  ActiveBackend create() => ActiveBackend();
}

String _$activeBackendHash() => r'e2d0073e8b3a4d83f307e3e174d935c7d7d62618';

/// The endpoint in force: the stored one, or the compiled default.
/// Startup reads the store directly (before any provider exists); this
/// provider is what Settings displays and edits.

abstract class _$ActiveBackend extends $AsyncNotifier<BackendEndpoint> {
  FutureOr<BackendEndpoint> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BackendEndpoint>, BackendEndpoint>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BackendEndpoint>, BackendEndpoint>,
              AsyncValue<BackendEndpoint>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// #1651 — the pending switch, read alongside the active endpoint.

@ProviderFor(pendingBackendSwitch)
final pendingBackendSwitchProvider = PendingBackendSwitchProvider._();

/// #1651 — the pending switch, read alongside the active endpoint.

final class PendingBackendSwitchProvider
    extends
        $FunctionalProvider<
          AsyncValue<BackendSwitchRecord?>,
          BackendSwitchRecord?,
          FutureOr<BackendSwitchRecord?>
        >
    with
        $FutureModifier<BackendSwitchRecord?>,
        $FutureProvider<BackendSwitchRecord?> {
  /// #1651 — the pending switch, read alongside the active endpoint.
  PendingBackendSwitchProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pendingBackendSwitchProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pendingBackendSwitchHash();

  @$internal
  @override
  $FutureProviderElement<BackendSwitchRecord?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<BackendSwitchRecord?> create(Ref ref) {
    return pendingBackendSwitch(ref);
  }
}

String _$pendingBackendSwitchHash() =>
    r'24e762d5daa15ac45f8824b45b6a6d057ef4e8b5';

@ProviderFor(backendProbeTransport)
final backendProbeTransportProvider = BackendProbeTransportProvider._();

final class BackendProbeTransportProvider
    extends
        $FunctionalProvider<
          BackendProbeTransportFactory,
          BackendProbeTransportFactory,
          BackendProbeTransportFactory
        >
    with $Provider<BackendProbeTransportFactory> {
  BackendProbeTransportProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'backendProbeTransportProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$backendProbeTransportHash();

  @$internal
  @override
  $ProviderElement<BackendProbeTransportFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  BackendProbeTransportFactory create(Ref ref) {
    return backendProbeTransport(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BackendProbeTransportFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BackendProbeTransportFactory>(value),
    );
  }
}

String _$backendProbeTransportHash() =>
    r'2e90d6a93c165097c793d29346c2017fef5a8402';
