// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'creation_intent.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(creationDraftStore)
final creationDraftStoreProvider = CreationDraftStoreProvider._();

final class CreationDraftStoreProvider
    extends
        $FunctionalProvider<
          CreationDraftStore,
          CreationDraftStore,
          CreationDraftStore
        >
    with $Provider<CreationDraftStore> {
  CreationDraftStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creationDraftStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creationDraftStoreHash();

  @$internal
  @override
  $ProviderElement<CreationDraftStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CreationDraftStore create(Ref ref) {
    return creationDraftStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreationDraftStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreationDraftStore>(value),
    );
  }
}

String _$creationDraftStoreHash() =>
    r'9bc16bed57a9ac2e5b5db94be1a325150194ddf5';

@ProviderFor(creationDrafts)
final creationDraftsProvider = CreationDraftsProvider._();

final class CreationDraftsProvider
    extends $FunctionalProvider<CreationDrafts, CreationDrafts, CreationDrafts>
    with $Provider<CreationDrafts> {
  CreationDraftsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'creationDraftsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$creationDraftsHash();

  @$internal
  @override
  $ProviderElement<CreationDrafts> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CreationDrafts create(Ref ref) {
    return creationDrafts(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CreationDrafts value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CreationDrafts>(value),
    );
  }
}

String _$creationDraftsHash() => r'f051e9a894359866e209dd57cdaa83a68c62f2c0';
