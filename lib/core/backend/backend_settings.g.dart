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

String _$activeBackendHash() => r'c455db5bfc1bd8f97b714288af5540002c5c5730';

/// The endpoint in force: the stored one, or the compiled default.
/// Startup reads the store directly (before any provider exists); this
/// provider is what Settings displays and edits.

abstract class _$ActiveBackend extends $AsyncNotifier<BackendEndpoint> {
  FutureOr<BackendEndpoint> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<BackendEndpoint>, BackendEndpoint>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<BackendEndpoint>, BackendEndpoint>,
              AsyncValue<BackendEndpoint>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
