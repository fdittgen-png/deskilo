// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_tax_reference.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(activeTaxReference)
final activeTaxReferenceProvider = ActiveTaxReferenceProvider._();

final class ActiveTaxReferenceProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  ActiveTaxReferenceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeTaxReferenceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeTaxReferenceHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return activeTaxReference(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$activeTaxReferenceHash() =>
    r'13e6d292b2589c90f69be61bbfeeda6a4755f41f';
