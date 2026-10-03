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

String _$directoryGeocoderHash() => r'cd23ab9df91cf199e79f14a4b5b3d705a60bce05';

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
    r'edbcd663e0cfd2ec82a4ea3c6dad312d0635b9b8';

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
