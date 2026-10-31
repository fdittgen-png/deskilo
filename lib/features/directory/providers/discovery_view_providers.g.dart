// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'discovery_view_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The device-local store of the discovery view preference.

@ProviderFor(discoveryViewStore)
final discoveryViewStoreProvider = DiscoveryViewStoreProvider._();

/// The device-local store of the discovery view preference.

final class DiscoveryViewStoreProvider
    extends
        $FunctionalProvider<
          DiscoveryViewStore,
          DiscoveryViewStore,
          DiscoveryViewStore
        >
    with $Provider<DiscoveryViewStore> {
  /// The device-local store of the discovery view preference.
  DiscoveryViewStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryViewStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryViewStoreHash();

  @$internal
  @override
  $ProviderElement<DiscoveryViewStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DiscoveryViewStore create(Ref ref) {
    return discoveryViewStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiscoveryViewStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiscoveryViewStore>(value),
    );
  }
}

String _$discoveryViewStoreHash() =>
    r'5479ab7d1f2020fbe5ec909537a53d392c6ec367';

/// The map services discovery's map is drawn from (#2488): the platform's
/// stored endpoints, else this build's, else the documented defaults. Until
/// the platform settings arrive (or signed out) the build's choice stands.

@ProviderFor(mapServices)
final mapServicesProvider = MapServicesProvider._();

/// The map services discovery's map is drawn from (#2488): the platform's
/// stored endpoints, else this build's, else the documented defaults. Until
/// the platform settings arrive (or signed out) the build's choice stands.

final class MapServicesProvider
    extends $FunctionalProvider<MapServices, MapServices, MapServices>
    with $Provider<MapServices> {
  /// The map services discovery's map is drawn from (#2488): the platform's
  /// stored endpoints, else this build's, else the documented defaults. Until
  /// the platform settings arrive (or signed out) the build's choice stands.
  MapServicesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapServicesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapServicesHash();

  @$internal
  @override
  $ProviderElement<MapServices> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MapServices create(Ref ref) {
    return mapServices(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MapServices value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MapServices>(value),
    );
  }
}

String _$mapServicesHash() => r'4430954c15add1947b5187e0f17b553b991efb41';

/// List or map, and the map provider accepted, for the signed-in person
/// at their personal home on this device. Signed out, the choice is held
/// for this screen only and nothing is written.

@ProviderFor(DiscoveryView)
final discoveryViewProvider = DiscoveryViewProvider._();

/// List or map, and the map provider accepted, for the signed-in person
/// at their personal home on this device. Signed out, the choice is held
/// for this screen only and nothing is written.
final class DiscoveryViewProvider
    extends $AsyncNotifierProvider<DiscoveryView, DiscoveryViewPreference> {
  /// List or map, and the map provider accepted, for the signed-in person
  /// at their personal home on this device. Signed out, the choice is held
  /// for this screen only and nothing is written.
  DiscoveryViewProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'discoveryViewProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$discoveryViewHash();

  @$internal
  @override
  DiscoveryView create() => DiscoveryView();
}

String _$discoveryViewHash() => r'cac863c42f388666b30d27a81ec9fa64287587b3';

/// List or map, and the map provider accepted, for the signed-in person
/// at their personal home on this device. Signed out, the choice is held
/// for this screen only and nothing is written.

abstract class _$DiscoveryView extends $AsyncNotifier<DiscoveryViewPreference> {
  FutureOr<DiscoveryViewPreference> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<DiscoveryViewPreference>,
              DiscoveryViewPreference
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<DiscoveryViewPreference>,
                DiscoveryViewPreference
              >,
              AsyncValue<DiscoveryViewPreference>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
