// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The one write of a service.

@ProviderFor(saveService)
final saveServiceProvider = SaveServiceProvider._();

/// The one write of a service.

final class SaveServiceProvider
    extends $FunctionalProvider<SaveService, SaveService, SaveService>
    with $Provider<SaveService> {
  /// The one write of a service.
  SaveServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveServiceHash();

  @$internal
  @override
  $ProviderElement<SaveService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaveService create(Ref ref) {
    return saveService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveService>(value),
    );
  }
}

String _$saveServiceHash() => r'd634ee1c85ffceb34df698914ec8e91c96efa29f';
