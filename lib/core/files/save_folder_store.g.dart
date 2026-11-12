// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_folder_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(saveFolderStore)
final saveFolderStoreProvider = SaveFolderStoreProvider._();

final class SaveFolderStoreProvider
    extends
        $FunctionalProvider<SaveFolderStore, SaveFolderStore, SaveFolderStore>
    with $Provider<SaveFolderStore> {
  SaveFolderStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveFolderStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveFolderStoreHash();

  @$internal
  @override
  $ProviderElement<SaveFolderStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaveFolderStore create(Ref ref) {
    return saveFolderStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveFolderStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveFolderStore>(value),
    );
  }
}

String _$saveFolderStoreHash() => r'beb3234295e0c7f15da29f295c3fef5c75622f0d';
