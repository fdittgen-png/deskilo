// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_location_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(directoryGeocoder)
final directoryGeocoderProvider = DirectoryGeocoderProvider._();

final class DirectoryGeocoderProvider
    extends
        $FunctionalProvider<
          DirectoryGeocoder,
          DirectoryGeocoder,
          DirectoryGeocoder
        >
    with $Provider<DirectoryGeocoder> {
  DirectoryGeocoderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directoryGeocoderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directoryGeocoderHash();

  @$internal
  @override
  $ProviderElement<DirectoryGeocoder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DirectoryGeocoder create(Ref ref) {
    return directoryGeocoder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectoryGeocoder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DirectoryGeocoder>(value),
    );
  }
}

String _$directoryGeocoderHash() => r'cb43baf49aec6f59cdeba41f1ff542bb0fc1658a';

/// #3689 -- the tiles of a map outside Discover (the public-page editor's
/// pin): null is the network; a test gives its own.

@ProviderFor(mapTileProvider)
final mapTileProviderProvider = MapTileProviderProvider._();

/// #3689 -- the tiles of a map outside Discover (the public-page editor's
/// pin): null is the network; a test gives its own.

final class MapTileProviderProvider
    extends $FunctionalProvider<TileProvider?, TileProvider?, TileProvider?>
    with $Provider<TileProvider?> {
  /// #3689 -- the tiles of a map outside Discover (the public-page editor's
  /// pin): null is the network; a test gives its own.
  MapTileProviderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapTileProviderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapTileProviderHash();

  @$internal
  @override
  $ProviderElement<TileProvider?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TileProvider? create(Ref ref) {
    return mapTileProvider(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TileProvider? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TileProvider?>(value),
    );
  }
}

String _$mapTileProviderHash() => r'42e3bba226b28221eb61f302205c30e980fb85fc';

/// #3684 -- the places found on this device, so a second visit asks the
/// geocoder nothing again.

@ProviderFor(directoryLocationMemory)
final directoryLocationMemoryProvider = DirectoryLocationMemoryProvider._();

/// #3684 -- the places found on this device, so a second visit asks the
/// geocoder nothing again.

final class DirectoryLocationMemoryProvider
    extends
        $FunctionalProvider<
          DirectoryLocationMemory,
          DirectoryLocationMemory,
          DirectoryLocationMemory
        >
    with $Provider<DirectoryLocationMemory> {
  /// #3684 -- the places found on this device, so a second visit asks the
  /// geocoder nothing again.
  DirectoryLocationMemoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directoryLocationMemoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directoryLocationMemoryHash();

  @$internal
  @override
  $ProviderElement<DirectoryLocationMemory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DirectoryLocationMemory create(Ref ref) {
    return directoryLocationMemory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectoryLocationMemory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DirectoryLocationMemory>(value),
    );
  }
}

String _$directoryLocationMemoryHash() =>
    r'1500c0d34893dc158886f30735bfbcfd01f6bedd';

/// #3684 -- the one queue every address lookup waits in: one request at a
/// time, paused between them, remembered answers first.

@ProviderFor(directoryLookups)
final directoryLookupsProvider = DirectoryLookupsProvider._();

/// #3684 -- the one queue every address lookup waits in: one request at a
/// time, paused between them, remembered answers first.

final class DirectoryLookupsProvider
    extends
        $FunctionalProvider<
          DirectoryLookups,
          DirectoryLookups,
          DirectoryLookups
        >
    with $Provider<DirectoryLookups> {
  /// #3684 -- the one queue every address lookup waits in: one request at a
  /// time, paused between them, remembered answers first.
  DirectoryLookupsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directoryLookupsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directoryLookupsHash();

  @$internal
  @override
  $ProviderElement<DirectoryLookups> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DirectoryLookups create(Ref ref) {
    return directoryLookups(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectoryLookups value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DirectoryLookups>(value),
    );
  }
}

String _$directoryLookupsHash() => r'ca9b8fb0b849b4dc744c9b380cedcfee6d816054';

@ProviderFor(directoryAddressLocation)
final directoryAddressLocationProvider = DirectoryAddressLocationFamily._();

final class DirectoryAddressLocationProvider
    extends
        $FunctionalProvider<
          AsyncValue<DirectoryLocation?>,
          DirectoryLocation?,
          FutureOr<DirectoryLocation?>
        >
    with
        $FutureModifier<DirectoryLocation?>,
        $FutureProvider<DirectoryLocation?> {
  DirectoryAddressLocationProvider._({
    required DirectoryAddressLocationFamily super.from,
    required String super.argument,
  }) : super(
         retry: _noRetry,
         name: r'directoryAddressLocationProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$directoryAddressLocationHash();

  @override
  String toString() {
    return r'directoryAddressLocationProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<DirectoryLocation?> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<DirectoryLocation?> create(Ref ref) {
    final argument = this.argument as String;
    return directoryAddressLocation(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is DirectoryAddressLocationProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$directoryAddressLocationHash() =>
    r'eacd6690001b9ab7b3dba45ccdda8b392892f027';

final class DirectoryAddressLocationFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<DirectoryLocation?>, String> {
  DirectoryAddressLocationFamily._()
    : super(
        retry: _noRetry,
        name: r'directoryAddressLocationProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  DirectoryAddressLocationProvider call(String address) =>
      DirectoryAddressLocationProvider._(argument: address, from: this);

  @override
  String toString() => r'directoryAddressLocationProvider';
}
