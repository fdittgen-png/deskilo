// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_vat_rates.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The VAT rates' one write.

@ProviderFor(saveVatRates)
final saveVatRatesProvider = SaveVatRatesProvider._();

/// The VAT rates' one write.

final class SaveVatRatesProvider
    extends $FunctionalProvider<SaveVatRates, SaveVatRates, SaveVatRates>
    with $Provider<SaveVatRates> {
  /// The VAT rates' one write.
  SaveVatRatesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveVatRatesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveVatRatesHash();

  @$internal
  @override
  $ProviderElement<SaveVatRates> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaveVatRates create(Ref ref) {
    return saveVatRates(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveVatRates value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveVatRates>(value),
    );
  }
}

String _$saveVatRatesHash() => r'f797ffb5b6d52f595916614ff1fed8fa494ccb9e';
