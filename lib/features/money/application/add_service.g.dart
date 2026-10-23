// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'add_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The services step's write of a new service.

@ProviderFor(addService)
final addServiceProvider = AddServiceProvider._();

/// The services step's write of a new service.

final class AddServiceProvider
    extends $FunctionalProvider<AddService, AddService, AddService>
    with $Provider<AddService> {
  /// The services step's write of a new service.
  AddServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'addServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$addServiceHash();

  @$internal
  @override
  $ProviderElement<AddService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AddService create(Ref ref) {
    return addService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AddService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AddService>(value),
    );
  }
}

String _$addServiceHash() => r'bd6bdd2c11d328321b5e81057ba4397158ae0ec4';
