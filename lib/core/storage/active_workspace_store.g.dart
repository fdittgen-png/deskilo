// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_workspace_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activeWorkspaceStore)
final activeWorkspaceStoreProvider = ActiveWorkspaceStoreProvider._();

final class ActiveWorkspaceStoreProvider
    extends
        $FunctionalProvider<
          ActiveWorkspaceStore,
          ActiveWorkspaceStore,
          ActiveWorkspaceStore
        >
    with $Provider<ActiveWorkspaceStore> {
  ActiveWorkspaceStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeWorkspaceStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeWorkspaceStoreHash();

  @$internal
  @override
  $ProviderElement<ActiveWorkspaceStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ActiveWorkspaceStore create(Ref ref) {
    return activeWorkspaceStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveWorkspaceStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveWorkspaceStore>(value),
    );
  }
}

String _$activeWorkspaceStoreHash() =>
    r'890709c93eab5c64532497c3421fc944045333cd';

@ProviderFor(defaultWorkspaceStore)
final defaultWorkspaceStoreProvider = DefaultWorkspaceStoreProvider._();

final class DefaultWorkspaceStoreProvider
    extends
        $FunctionalProvider<
          DefaultWorkspaceStore,
          DefaultWorkspaceStore,
          DefaultWorkspaceStore
        >
    with $Provider<DefaultWorkspaceStore> {
  DefaultWorkspaceStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'defaultWorkspaceStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$defaultWorkspaceStoreHash();

  @$internal
  @override
  $ProviderElement<DefaultWorkspaceStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DefaultWorkspaceStore create(Ref ref) {
    return defaultWorkspaceStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DefaultWorkspaceStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DefaultWorkspaceStore>(value),
    );
  }
}

String _$defaultWorkspaceStoreHash() =>
    r'eede3cb778891b197ac026fd6604e3d76c93b371';
