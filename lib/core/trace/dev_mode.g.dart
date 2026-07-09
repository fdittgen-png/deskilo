// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dev_mode.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(devModeStore)
final devModeStoreProvider = DevModeStoreProvider._();

final class DevModeStoreProvider
    extends $FunctionalProvider<DevModeStore, DevModeStore, DevModeStore>
    with $Provider<DevModeStore> {
  DevModeStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devModeStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devModeStoreHash();

  @$internal
  @override
  $ProviderElement<DevModeStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DevModeStore create(Ref ref) {
    return devModeStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DevModeStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DevModeStore>(value),
    );
  }
}

String _$devModeStoreHash() => r'deb207acde934b94c24b1d436d293f4d7a552cbf';

/// Whether developer mode is on. Local diagnostics only — visible to every
/// user, default off, never synced to the backend.

@ProviderFor(DevMode)
final devModeProvider = DevModeProvider._();

/// Whether developer mode is on. Local diagnostics only — visible to every
/// user, default off, never synced to the backend.
final class DevModeProvider extends $AsyncNotifierProvider<DevMode, bool> {
  /// Whether developer mode is on. Local diagnostics only — visible to every
  /// user, default off, never synced to the backend.
  DevModeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'devModeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$devModeHash();

  @$internal
  @override
  DevMode create() => DevMode();
}

String _$devModeHash() => r'e384cb227979db1960b0207f736d3645042e385d';

/// Whether developer mode is on. Local diagnostics only — visible to every
/// user, default off, never synced to the backend.

abstract class _$DevMode extends $AsyncNotifier<bool> {
  FutureOr<bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<bool>, bool>,
              AsyncValue<bool>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
