// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'saved_places_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The device-local store of saved public pages.

@ProviderFor(savedPlacesStore)
final savedPlacesStoreProvider = SavedPlacesStoreProvider._();

/// The device-local store of saved public pages.

final class SavedPlacesStoreProvider
    extends
        $FunctionalProvider<
          SavedPlacesStore,
          SavedPlacesStore,
          SavedPlacesStore
        >
    with $Provider<SavedPlacesStore> {
  /// The device-local store of saved public pages.
  SavedPlacesStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedPlacesStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedPlacesStoreHash();

  @$internal
  @override
  $ProviderElement<SavedPlacesStore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SavedPlacesStore create(Ref ref) {
    return savedPlacesStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SavedPlacesStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SavedPlacesStore>(value),
    );
  }
}

String _$savedPlacesStoreHash() => r'5a79e39c41176a86c683627573f014fcf06ada1c';

/// The namespace the signed-in person's saved places live under: their
/// canonical identity at their personal home. Null while nobody is signed
/// in there, so an anonymous visitor has nowhere to save to and sees no
/// one else's list. A selected workspace does not enter into it.

@ProviderFor(savedPlacesNamespace)
final savedPlacesNamespaceProvider = SavedPlacesNamespaceProvider._();

/// The namespace the signed-in person's saved places live under: their
/// canonical identity at their personal home. Null while nobody is signed
/// in there, so an anonymous visitor has nowhere to save to and sees no
/// one else's list. A selected workspace does not enter into it.

final class SavedPlacesNamespaceProvider
    extends $FunctionalProvider<AsyncValue<String?>, String?, FutureOr<String?>>
    with $FutureModifier<String?>, $FutureProvider<String?> {
  /// The namespace the signed-in person's saved places live under: their
  /// canonical identity at their personal home. Null while nobody is signed
  /// in there, so an anonymous visitor has nowhere to save to and sees no
  /// one else's list. A selected workspace does not enter into it.
  SavedPlacesNamespaceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedPlacesNamespaceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedPlacesNamespaceHash();

  @$internal
  @override
  $FutureProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<String?> create(Ref ref) {
    return savedPlacesNamespace(ref);
  }
}

String _$savedPlacesNamespaceHash() =>
    r'd90ecab9c6ae4711be39f2bf76ac6ec1c0088cbd';

/// The person's saved places on this device; empty while signed out.

@ProviderFor(SavedPlaces)
final savedPlacesProvider = SavedPlacesProvider._();

/// The person's saved places on this device; empty while signed out.
final class SavedPlacesProvider
    extends $AsyncNotifierProvider<SavedPlaces, List<SavedPlace>> {
  /// The person's saved places on this device; empty while signed out.
  SavedPlacesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'savedPlacesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$savedPlacesHash();

  @$internal
  @override
  SavedPlaces create() => SavedPlaces();
}

String _$savedPlacesHash() => r'16cbf00667b876930bdb230730872d1d14cc9781';

/// The person's saved places on this device; empty while signed out.

abstract class _$SavedPlaces extends $AsyncNotifier<List<SavedPlace>> {
  FutureOr<List<SavedPlace>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<SavedPlace>>, List<SavedPlace>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<SavedPlace>>, List<SavedPlace>>,
              AsyncValue<List<SavedPlace>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Whether the discovery list shows only the places saved on this device.

@ProviderFor(DiscoverSavedOnly)
final discoverSavedOnlyProvider = DiscoverSavedOnlyProvider._();

/// Whether the discovery list shows only the places saved on this device.
final class DiscoverSavedOnlyProvider
    extends $NotifierProvider<DiscoverSavedOnly, bool> {
  /// Whether the discovery list shows only the places saved on this device.
  DiscoverSavedOnlyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoverSavedOnlyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoverSavedOnlyHash();

  @$internal
  @override
  DiscoverSavedOnly create() => DiscoverSavedOnly();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$discoverSavedOnlyHash() => r'3e56ba7171baf4041a1c250e379e1e5fd3aa80b6';

/// Whether the discovery list shows only the places saved on this device.

abstract class _$DiscoverSavedOnly extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
