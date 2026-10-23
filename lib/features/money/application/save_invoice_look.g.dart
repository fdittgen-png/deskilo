// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_invoice_look.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The setup guide's write of the invoice look.

@ProviderFor(saveInvoiceLook)
final saveInvoiceLookProvider = SaveInvoiceLookProvider._();

/// The setup guide's write of the invoice look.

final class SaveInvoiceLookProvider
    extends
        $FunctionalProvider<SaveInvoiceLook, SaveInvoiceLook, SaveInvoiceLook>
    with $Provider<SaveInvoiceLook> {
  /// The setup guide's write of the invoice look.
  SaveInvoiceLookProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'saveInvoiceLookProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$saveInvoiceLookHash();

  @$internal
  @override
  $ProviderElement<SaveInvoiceLook> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SaveInvoiceLook create(Ref ref) {
    return saveInvoiceLook(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SaveInvoiceLook value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SaveInvoiceLook>(value),
    );
  }
}

String _$saveInvoiceLookHash() => r'b3a4f939a037016968f72e553bb2f2e583405361';
