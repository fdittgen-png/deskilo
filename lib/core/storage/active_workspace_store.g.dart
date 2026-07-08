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
