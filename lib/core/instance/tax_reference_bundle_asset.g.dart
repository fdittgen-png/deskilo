// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tax_reference_bundle_asset.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// How the app reads the bundled copy -- the asset, or a canned set in tests.
/// It is what a self-hosted or F-Droid build stands on when the installation
/// cannot answer: no default server is assumed.

@ProviderFor(taxReferenceBundleLoader)
final taxReferenceBundleLoaderProvider = TaxReferenceBundleLoaderProvider._();

/// How the app reads the bundled copy -- the asset, or a canned set in tests.
/// It is what a self-hosted or F-Droid build stands on when the installation
/// cannot answer: no default server is assumed.

final class TaxReferenceBundleLoaderProvider
    extends
        $FunctionalProvider<
          Future<TaxReferenceSet> Function(),
          Future<TaxReferenceSet> Function(),
          Future<TaxReferenceSet> Function()
        >
    with $Provider<Future<TaxReferenceSet> Function()> {
  /// How the app reads the bundled copy -- the asset, or a canned set in tests.
  /// It is what a self-hosted or F-Droid build stands on when the installation
  /// cannot answer: no default server is assumed.
  TaxReferenceBundleLoaderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'taxReferenceBundleLoaderProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$taxReferenceBundleLoaderHash();

  @$internal
  @override
  $ProviderElement<Future<TaxReferenceSet> Function()> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  Future<TaxReferenceSet> Function() create(Ref ref) {
    return taxReferenceBundleLoader(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Future<TaxReferenceSet> Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Future<TaxReferenceSet> Function()>(
        value,
      ),
    );
  }
}

String _$taxReferenceBundleLoaderHash() =>
    r'e12a9b43fb4cd5eb176522e3ac6bb32b0cd73f9a';
