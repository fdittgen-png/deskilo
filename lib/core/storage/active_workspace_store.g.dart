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
    r'21ba45928f8e88c75d53e449eed9500eff45b684';

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
    r'1f40cfb66fbf8bc6b43c18388ac32634152cc5a3';
