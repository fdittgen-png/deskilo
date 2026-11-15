// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_original_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(invoiceOriginalRepository)
final invoiceOriginalRepositoryProvider = InvoiceOriginalRepositoryProvider._();

final class InvoiceOriginalRepositoryProvider
    extends
        $FunctionalProvider<
          InvoiceOriginalRepository,
          InvoiceOriginalRepository,
          InvoiceOriginalRepository
        >
    with $Provider<InvoiceOriginalRepository> {
  InvoiceOriginalRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'invoiceOriginalRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$invoiceOriginalRepositoryHash();

  @$internal
  @override
  $ProviderElement<InvoiceOriginalRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  InvoiceOriginalRepository create(Ref ref) {
    return invoiceOriginalRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InvoiceOriginalRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InvoiceOriginalRepository>(value),
    );
  }
}

String _$invoiceOriginalRepositoryHash() =>
    r'112f0e1b5268a50ec5508490a50b3c18f3396385';
